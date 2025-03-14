"""Tests for DKMS configuration and module loading."""

from typing import Dict, Any
import os
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
    assert "template" in dkms_config, "Should use template module"
    assert dkms_config["template"]["dest"].endswith(
        "dkms.conf"
    ), "Should create dkms.conf file"

    # Verify DKMS build task
    dkms_build_tasks = [
        task for task in dkms_tasks if task["name"] == "Build and install with DKMS"
    ]
    assert len(dkms_build_tasks) == 1, "Should have exactly one DKMS build task"

    dkms_build = dkms_build_tasks[0]
    assert "command" in dkms_build, "Should use command module"
    assert "dkms install" in dkms_build["command"]["cmd"], "Should install with DKMS"


def test_module_autoload_configuration() -> None:
    """Test that module autoload is configured correctly."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks_content = yaml.safe_load(f)

    # Find module autoload task
    autoload_tasks = [
        task
        for task in tasks_content
        if isinstance(task, dict)
        and "name" in task
        and task["name"] == "Configure module autoload"
    ]
    assert len(autoload_tasks) == 1, "Should have exactly one autoload task"

    autoload = autoload_tasks[0]
    assert "copy" in autoload, "Should use copy module"
    assert autoload["copy"]["dest"].endswith(
        "acer-wmi-battery.conf"
    ), "Should create module config file"
    assert "notify" in autoload, "Should notify handler"
