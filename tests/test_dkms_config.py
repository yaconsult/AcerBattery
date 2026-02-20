"""Tests for DKMS configuration and module loading."""

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
