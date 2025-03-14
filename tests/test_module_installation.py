"""Tests for the Acer WMI Battery module installation."""

from typing import Dict, Any, cast
import pytest
from ansible.parsing.dataloader import DataLoader
from ansible.inventory.manager import InventoryManager
from ansible.inventory.host import Host
import yaml


def test_inventory_file() -> None:
    """Test that the inventory file is valid."""
    loader = DataLoader()
    inventory = InventoryManager(loader=loader, sources=["inventory"])

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
    """Test that package installation task is distribution-agnostic."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks = yaml.safe_load(f)

    # Find package installation task
    pkg_tasks = [
        task
        for task in tasks
        if isinstance(task, dict) and task.get("name") == "Install required packages"
    ]
    assert len(pkg_tasks) == 1, "Should have exactly one package installation task"

    pkg_task = pkg_tasks[0]
    assert pkg_task["package"]["state"] == "present", "Should install packages"
    assert "{{ item }}" in str(
        pkg_task["package"]["name"]
    ), "Should use item variable for package names"
    assert "{{ packages[ansible_os_family] }}" in str(
        pkg_task["loop"]
    ), "Should loop over distribution-specific packages"
