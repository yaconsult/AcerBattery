"""Tests for DKMS configuration and module loading."""

from pathlib import Path
import yaml


def test_dkms_config_file_exists() -> None:
    """Test that DKMS configuration file exists."""
    with open("roles/acer_battery/templates/dkms.conf.j2", "r") as f:
        dkms_content = f.read()

    assert "PACKAGE_NAME" in dkms_content, "Should define package name"
    assert "PACKAGE_VERSION" in dkms_content, "Should define package version"
    assert "AUTOINSTALL" in dkms_content, "Should enable auto-installation"


def test_task_file_contains_dkms_config() -> None:
    """Test that main task file includes DKMS configuration."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks_content = yaml.safe_load(f)

    # Find DKMS related tasks
    dkms_tasks = [
        task
        for task in tasks_content
        if isinstance(task, dict)
        and "name" in task
        and ("DKMS" in task["name"] or "dkms" in task["name"])
    ]

    assert len(dkms_tasks) >= 2, "Should have at least 2 DKMS related tasks"

    # Verify DKMS configuration task
    dkms_config_tasks = [
        task for task in dkms_tasks if task["name"] == "Install DKMS configuration"
    ]
    assert len(dkms_config_tasks) == 1, "Should have exactly one DKMS config task"

    dkms_config = dkms_config_tasks[0]
    assert "ansible.builtin.template" in dkms_config, "Should use template module"
    assert dkms_config["ansible.builtin.template"]["dest"].endswith(
        "dkms.conf"
    ), "Should create dkms.conf file"


def test_module_autoload_configuration() -> None:
    """Test that module autoload is configured correctly."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks_content = yaml.safe_load(f)

    template_tasks = [
        task
        for task in tasks_content
        if isinstance(task, dict) and task.get("ansible.builtin.template") is not None
    ]

    service_tasks = [
        task
        for task in template_tasks
        if task["ansible.builtin.template"].get("dest")
        == "/etc/systemd/system/acer-wmi-battery.service"
    ]
    assert len(service_tasks) == 1, "Should install systemd service"

    file_tasks = [
        task
        for task in tasks_content
        if isinstance(task, dict) and task.get("ansible.builtin.file") is not None
    ]

    modules_load_absent_tasks = [
        task
        for task in file_tasks
        if task["ansible.builtin.file"].get("path")
        == "/etc/modules-load.d/acer-wmi-battery.conf"
        and task["ansible.builtin.file"].get("state") == "absent"
    ]
    assert (
        len(modules_load_absent_tasks) == 1
    ), "Should remove modules-load.d config (avoid early-boot stale DKMS artifacts)"


def test_dkms_make_passes_kernelrelease() -> None:
    """Test that DKMS MAKE directive passes KERNELRELEASE to avoid uname -r fallback."""
    with open("roles/acer_battery/templates/dkms.conf.j2", "r") as f:
        content = f.read()

    assert "KERNELRELEASE" in content, "MAKE should pass KERNELRELEASE to the build"
    assert "${kernelver}" in content, "Should use DKMS kernelver variable"


def test_orphaned_modules_load_template_removed() -> None:
    """modules-load.conf.j2 should not exist (replaced by systemd service)."""
    path = Path("roles/acer_battery/templates/modules-load.conf.j2")
    assert not path.exists(), (
        "Orphaned modules-load.conf.j2 template should be deleted"
    )


def test_no_hardcoded_version_in_load_module_task() -> None:
    """Load module task should use {{ acer_battery_version }}, not hardcoded 'main'."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        raw = f.read()

    # Find the "Load module" task block
    in_load_block = False
    load_block_lines: list[str] = []
    for line in raw.splitlines():
        if "name: Load module" in line:
            in_load_block = True
        elif in_load_block and line.startswith("- name:"):
            break
        if in_load_block:
            load_block_lines.append(line)

    load_block = "\n".join(load_block_lines)
    assert "-v main" not in load_block, (
        "Load module task should use {{ acer_battery_version }}, not hardcoded 'main'"
    )


def test_module_check_uses_dynamic_find() -> None:
    """Module existence check should use find, not a hardcoded path."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks = yaml.safe_load(f)

    locate_tasks = [
        t for t in tasks
        if isinstance(t, dict) and "name" in t and "Locate installed module" in t["name"]
    ]
    assert len(locate_tasks) == 1, "Should have a dynamic module locate task"

    # Should NOT have a stat task checking the old hardcoded path
    stat_tasks = [
        t for t in tasks
        if isinstance(t, dict)
        and t.get("ansible.builtin.stat") is not None
        and "updates/dkms" in str(t.get("ansible.builtin.stat", {}).get("path", ""))
    ]
    assert len(stat_tasks) == 0, "Should not use hardcoded /updates/dkms/ module path"


def test_kernel_install_hook_is_installed() -> None:
    """Test that a kernel-install hook is installed (Fedora/RHEL kernel updates)."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks_content = yaml.safe_load(f)

    template_tasks = [
        task
        for task in tasks_content
        if isinstance(task, dict) and task.get("ansible.builtin.template") is not None
    ]

    kernel_install_tasks = [
        task
        for task in template_tasks
        if task["ansible.builtin.template"].get("dest")
        == "/etc/kernel/install.d/90-acer-wmi-battery.install"
    ]
    assert len(kernel_install_tasks) == 1, "Should install kernel-install hook"
