"""Tests for the Acer WMI Battery module installation."""

from typing import Dict, Any, cast
import pytest
from ansible.parsing.dataloader import DataLoader
from ansible.inventory.manager import InventoryManager
from ansible.inventory.host import Host


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


@pytest.mark.parametrize(
    "os_family,package_manager,display_name",
    [
        ("Debian", "apt", "Debian/Ubuntu"),
        ("RedHat", "dnf", "RedHat/Fedora"),
    ],
)
def test_package_installation_tasks(
    os_family: str, package_manager: str, display_name: str
) -> None:
    """Test that package installation tasks are correct for different distributions."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks_content = f.read()

    # Verify distribution-specific package installation
    assert f"name: Install required packages ({display_name})" in tasks_content
    assert f"{package_manager}:" in tasks_content
    assert f'when: ansible_os_family == "{os_family}"' in tasks_content
