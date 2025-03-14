"""Tests for DKMS configuration and module loading."""

from typing import Dict, Any
import os
import yaml


def test_dkms_config_file_exists() -> None:
    """Test that DKMS configuration template exists."""
    template_path = "roles/acer_battery/templates/dkms.conf.j2"
    assert os.path.exists(template_path), "DKMS template file should exist"


def test_task_file_contains_dkms_config() -> None:
    """Test that main task file includes DKMS configuration."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks_content = yaml.safe_load(f)

    # Find DKMS related tasks
    dkms_tasks = [
        task
        for task in tasks_content
        if isinstance(task, dict) and "name" in task and "DKMS" in task["name"]
    ]

    assert len(dkms_tasks) >= 2, "Should have at least 2 DKMS related tasks"

    # Verify DKMS configuration task
    dkms_config_tasks = [
        task for task in dkms_tasks if "Install DKMS configuration" in task["name"]
    ]
    assert len(dkms_config_tasks) == 1, "Should have exactly one DKMS config task"

    dkms_config = dkms_config_tasks[0]
    assert "template" in dkms_config, "Should use template module"
    assert dkms_config["template"]["dest"].endswith(
        "dkms.conf"
    ), "Should create dkms.conf file"

    # Verify DKMS build task
    dkms_build_tasks = [
        task for task in dkms_tasks if "Build and install with DKMS" in task["name"]
    ]
    assert len(dkms_build_tasks) == 1, "Should have exactly one DKMS build task"

    dkms_build = dkms_build_tasks[0]
    assert "command" in dkms_build, "Should use command module"
    assert (
        "dkms install" in dkms_build["command"]["cmd"]
    ), "Should run dkms install command"


def test_module_autoload_configuration() -> None:
    """Test that module is configured to load at boot."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks_content = yaml.safe_load(f)

    # Find module loading tasks
    load_tasks = [
        task
        for task in tasks_content
        if isinstance(task, dict)
        and "name" in task
        and "module" in task["name"].lower()
    ]

    assert len(load_tasks) >= 2, "Should have at least 2 module loading tasks"

    # Verify immediate module loading
    modprobe_tasks = [
        task
        for task in load_tasks
        if task.get("modprobe", {}).get("name") == "acer-wmi-battery"
    ]
    assert len(modprobe_tasks) == 1, "Should have exactly one modprobe task"

    # Verify boot-time module loading
    boot_tasks = [task for task in load_tasks if "boot" in task["name"].lower()]
    assert len(boot_tasks) == 1, "Should have exactly one boot config task"

    boot_task = boot_tasks[0]
    assert boot_task["lineinfile"]["path"].endswith(
        "acer-wmi-battery.conf"
    ), "Should create proper module load config file"
    assert (
        boot_task["lineinfile"]["line"] == "acer-wmi-battery"
    ), "Should configure correct module name"
