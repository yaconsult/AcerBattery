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


def test_repository_update_tasks() -> None:
    """Test that repository update tasks are configured correctly."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks = yaml.safe_load(f)

    # Find git tasks
    git_tasks = [
        task for task in tasks if isinstance(task, dict) and task.get("git") is not None
    ]
    assert len(git_tasks) == 2, "Should have clone and update tasks for git"

    # Test clone task
    clone_task = next(
        task for task in git_tasks if task.get("name", "").startswith("Clone")
    )
    assert clone_task["git"]["update"] is True, "Clone should allow updates"
    assert clone_task["git"]["force"] is True, "Clone should use force"
    assert clone_task["git"]["version"] == "master", "Should track master branch"
    assert "when" in clone_task, "Clone should have condition"

    # Test update task
    update_task = next(
        task for task in git_tasks if task.get("name", "").startswith("Update")
    )
    assert update_task["git"]["update"] is True, "Update should check upstream"
    assert update_task["git"]["version"] == "master", "Should track master branch"
    assert "when" in update_task, "Update should have condition"
    assert "notify" in update_task, "Update should notify handler"


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
        load["modprobe"]["state"] == "present"
    ), "Load should ensure module is present"
