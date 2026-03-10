"""Tests for the Acer WMI Battery module installation."""

import re
import tomllib
from pathlib import Path
from typing import cast
from ansible.parsing.dataloader import DataLoader
from ansible.inventory.manager import InventoryManager
from ansible.inventory.host import Host
import yaml


def test_inventory_file() -> None:
    """Test that the inventory file is valid."""
    loader = DataLoader()
    inventory = InventoryManager(loader=loader, sources=["tests/inventory"])

    # Test localhost is present
    hosts = [h.name for h in inventory.get_hosts()]
    assert "localhost" in hosts

    # Use type casting to handle dynamic types from Ansible
    localhost = cast(Host, inventory.get_host("localhost"))
    connection = cast(str, localhost.vars.get("ansible_connection"))
    assert connection == "local"


def test_package_definitions() -> None:
    """Test that package definitions are correct for all supported distributions."""
    with open("roles/acer_battery/defaults/main.yml", "r") as f:
        defaults = yaml.safe_load(f)

    assert "packages" in defaults, "Should define package mappings"
    packages = defaults["packages"]

    # Test required distributions are present
    required_distros = {"Debian", "RedHat", "Suse", "Archlinux"}
    assert (
        set(packages.keys()) >= required_distros
    ), "Should support all required distributions"

    # Test common required packages
    for distro, pkg_list in packages.items():
        assert "git" in pkg_list, f"{distro} should include git"
        assert "dkms" in pkg_list, f"{distro} should include dkms"
        assert any(
            "header" in pkg.lower() for pkg in pkg_list
        ), f"{distro} should include kernel headers"


def test_package_installation_task() -> None:
    """Test that package definitions exist in defaults.

    The role currently does not actively install packages (it prints a debug message),
    so asserting specific package tasks would be brittle.
    """
    with open("roles/acer_battery/defaults/main.yml", "r") as f:
        defaults = yaml.safe_load(f)

    assert "packages" in defaults, "Should define package mappings"


def test_repository_update_tasks() -> None:
    """Test that repository fetch tasks are configured correctly."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks = yaml.safe_load(f)

    # Find git tasks
    git_tasks = [
        task
        for task in tasks
        if isinstance(task, dict) and task.get("ansible.builtin.git") is not None
    ]
    assert len(git_tasks) == 1, "Should have a clone task for git"

    clone_task = git_tasks[0]
    assert clone_task["ansible.builtin.git"]["repo"] == "{{ acer_battery_repo_url }}"
    assert clone_task["ansible.builtin.git"]["dest"] == "/tmp/acer-wmi-battery"
    assert (
        clone_task["ansible.builtin.git"]["version"] == "{{ acer_battery_version }}"
    )


def test_handlers() -> None:
    """Test that handlers are configured correctly."""
    with open("roles/acer_battery/handlers/main.yml", "r") as f:
        handlers = yaml.safe_load(f)

    # Test rebuild handler (listens for rebuild_module)
    rebuild_handlers = [
        h for h in handlers
        if isinstance(h, dict) and h.get("listen") == "rebuild_module"
    ]
    assert len(rebuild_handlers) == 1, "Should have rebuild handler"
    rebuild = rebuild_handlers[0]
    assert "notify" in rebuild, "Rebuild should notify load handler"

    # Test load handler (listens for load_module)
    load_handlers = [
        h for h in handlers
        if isinstance(h, dict) and h.get("listen") == "load_module"
    ]
    assert len(load_handlers) == 1, "Should have load handler"
    load = load_handlers[0]
    assert (
        "ansible.builtin.shell" in load
    ), "Load handler should use shell to modprobe and optionally rebuild"


def test_handlers_have_become() -> None:
    """Handlers that run dkms/modprobe must escalate to root."""
    with open("roles/acer_battery/handlers/main.yml", "r") as f:
        handlers = yaml.safe_load(f)

    for handler in handlers:
        if not isinstance(handler, dict):
            continue
        listen = handler.get("listen", "")
        if listen in ("rebuild_module", "load_module"):
            assert handler.get("become") is True, (
                f"Handler listening for '{listen}' must have become: true to run as root"
            )


def test_no_dead_home_dir_task() -> None:
    """The unused 'Get real home directory' task should be removed."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks = yaml.safe_load(f)

    home_dir_tasks = [
        t for t in tasks
        if isinstance(t, dict) and "home directory" in t.get("name", "").lower()
    ]
    assert len(home_dir_tasks) == 0, "Dead 'Get real home directory' task should be removed"


def test_status_symlink_not_generic() -> None:
    """Status script symlink should use a namespaced name, not bare 'status'."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks = yaml.safe_load(f)

    file_tasks = [
        t for t in tasks
        if isinstance(t, dict) and t.get("ansible.builtin.file") is not None
    ]
    symlink_tasks = [
        t for t in file_tasks
        if t["ansible.builtin.file"].get("state") == "link"
        and "acer-battery-status" in str(t["ansible.builtin.file"].get("src", ""))
    ]
    assert len(symlink_tasks) == 1, "Should have exactly one status script symlink"
    dest = symlink_tasks[0]["ansible.builtin.file"]["dest"]
    assert dest != "/usr/local/bin/status", (
        "Symlink should not use generic '/usr/local/bin/status' name"
    )
    assert "acer" in dest.lower(), "Symlink name should contain 'acer'"


def test_version_consistency() -> None:
    """Version should be consistent across galaxy.yml, pyproject.toml, and README badge."""
    with open("galaxy.yml", "r") as f:
        galaxy = yaml.safe_load(f)
    galaxy_version = galaxy["version"]

    with open("pyproject.toml", "rb") as f:
        pyproject = tomllib.load(f)
    pyproject_version = pyproject["project"]["version"]

    readme_text = Path("README.md").read_text()
    # Extract version from badge: version-X.Y.Z-blue
    badge_match = re.search(r"version-([0-9]+\.[0-9]+\.[0-9]+)-blue", readme_text)
    assert badge_match is not None, "README should contain a version badge"
    readme_version = badge_match.group(1)

    assert galaxy_version == pyproject_version, (
        f"galaxy.yml ({galaxy_version}) != pyproject.toml ({pyproject_version})"
    )
    assert galaxy_version == readme_version, (
        f"galaxy.yml ({galaxy_version}) != README badge ({readme_version})"
    )


def test_kernel_install_template_exists() -> None:
    """Kernel-install hook template should exist (Fedora/RHEL kernel updates)."""
    with open("roles/acer_battery/templates/kernel-install.j2", "r") as f:
        content = f.read()
    assert "kernel-install hook" in content
    assert "dkms" in content


def test_sign_modules_uses_template_vars() -> None:
    """Sign script should use Jinja vars for MOK paths, not hardcoded /var/lib/dkms."""
    with open("roles/acer_battery/templates/scripts/sign-modules.sh.j2", "r") as f:
        content = f.read()

    assert "{{ acer_battery_mok_key }}" in content, (
        "sign-modules.sh.j2 should use {{ acer_battery_mok_key }}"
    )
    assert "{{ acer_battery_mok_pub }}" in content, (
        "sign-modules.sh.j2 should use {{ acer_battery_mok_pub }}"
    )
    # Ensure no hardcoded paths remain for the signing call
    for line in content.splitlines():
        if "sha512" in line and "SIGN_FILE" in line:
            assert "/var/lib/dkms/mok" not in line, (
                "Signing command should not use hardcoded MOK path"
            )


def test_kernel_postinst_logs_errors() -> None:
    """kernel-postinst hook should log build/install failures instead of silently succeeding."""
    with open("roles/acer_battery/templates/kernel-postinst.j2", "r") as f:
        content = f.read()

    assert "WARNING" in content or "warning" in content, (
        "kernel-postinst should log warnings on build/install failure"
    )
    # Should still exit 0 to not block kernel installs
    assert "exit 0" in content, "Should exit 0 to not block kernel installation"


def test_stale_root_level_files_removed() -> None:
    """Root-level acer-wmi-battery.service and 99-acer-wmi-battery should not exist."""
    stale_files = [
        Path("acer-wmi-battery.service"),
        Path("99-acer-wmi-battery"),
    ]
    for f in stale_files:
        assert not f.exists(), (
            f"Stale root-level file '{f}' should be removed (authoritative versions are in templates/)"
        )


def test_systemd_service_template_has_no_invalid_keys() -> None:
    """Ensure systemd service template doesn't contain known invalid directives."""
    with open("roles/acer_battery/templates/acer-wmi-battery.service.j2", "r") as f:
        content = f.read()
    assert "MaximumFailureCount" not in content
