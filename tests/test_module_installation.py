"""Tests for the Acer WMI Battery module installation."""
from typing import Dict, Any
import pytest
from ansible.parsing.dataloader import DataLoader
from ansible.template import Templar
from ansible.inventory.manager import InventoryManager


def test_dkms_conf_template(tmp_path) -> None:
    """Test that the DKMS configuration template is valid."""
    # Setup
    loader = DataLoader()
    templar = Templar(loader)
    variables = {
        "acer_battery_version": "1.0"
    }
    
    # Test template rendering
    with open("roles/acer_battery/templates/dkms.conf.j2", "r") as f:
        template_content = f.read()
    
    rendered = templar.template(template_content, variables=variables)
    
    # Assertions
    assert "PACKAGE_NAME=\"acer-wmi-battery\"" in rendered
    assert "PACKAGE_VERSION=\"1.0\"" in rendered
    assert "AUTOINSTALL=\"yes\"" in rendered


def test_inventory_file() -> None:
    """Test that the inventory file is valid."""
    loader = DataLoader()
    inventory = InventoryManager(loader=loader, sources=["inventory"])
    
    # Test localhost is present
    assert "localhost" in [h.name for h in inventory.get_hosts()]
    assert inventory.get_host("localhost").vars.get("ansible_connection") == "local"


@pytest.mark.parametrize("os_family,package_manager", [
    ("Debian", "apt"),
    ("RedHat", "dnf")
])
def test_package_installation_tasks(os_family: str, package_manager: str) -> None:
    """Test that package installation tasks are correct for different distributions."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks_content = f.read()
    
    # Verify distribution-specific package installation
    assert f"name: Install required packages ({os_family})" in tasks_content
    assert f"{package_manager}:" in tasks_content
    assert "when: ansible_os_family ==" in tasks_content
