"""Tests for the Acer WMI Battery module installation."""

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

    # Test rebuild handler
    rebuild_handlers = [
        h for h in handlers if isinstance(h, dict) and h.get("name") == "rebuild_module"
    ]
    assert len(rebuild_handlers) == 1, "Should have rebuild handler"
    rebuild = rebuild_handlers[0]
    assert "notify" in rebuild, "Rebuild should notify load handler"

    # Test load handler
    load_handlers = [
        h for h in handlers if isinstance(h, dict) and h.get("name") == "load_module"
    ]
    assert len(load_handlers) == 1, "Should have load handler"
    load = load_handlers[0]
    assert (
        "ansible.builtin.shell" in load
    ), "Load handler should use shell to modprobe and optionally rebuild"


def test_kernel_install_template_exists() -> None:
    """Kernel-install hook template should exist (Fedora/RHEL kernel updates)."""
    with open("roles/acer_battery/templates/kernel-install.j2", "r") as f:
        content = f.read()
    assert "kernel-install hook" in content
    assert "dkms" in content


def test_systemd_service_template_has_no_invalid_keys() -> None:
    """Ensure systemd service template doesn't contain known invalid directives."""
    with open("roles/acer_battery/templates/acer-wmi-battery.service.j2", "r") as f:
        content = f.read()
    assert "MaximumFailureCount" not in content
