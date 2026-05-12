"""Tests for Secure Boot bootloader verification functionality."""

import yaml


def test_bootloader_verification_tasks_exist() -> None:
    """Test that bootloader verification tasks are present in main.yml."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks = yaml.safe_load(f)

    # Find bootloader verification tasks
    task_names = [
        task.get("name", "")
        for task in tasks
        if isinstance(task, dict) and "name" in task
    ]

    assert any(
        "bootloader files exist" in name.lower() for name in task_names
    ), "Should check if bootloader files exist"

    assert any(
        "verify bootloader packages" in name.lower() for name in task_names
    ), "Should verify bootloader package integrity"

    assert any(
        "warn if bootloader" in name.lower() for name in task_names
    ), "Should warn about unsigned bootloaders"


def test_bootloader_check_targets_correct_files() -> None:
    """Test that bootloader verification checks the correct EFI files."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks = yaml.safe_load(f)

    # Find the stat task for bootloader files
    bootloader_stat_tasks = [
        task
        for task in tasks
        if isinstance(task, dict)
        and task.get("name", "").lower().find("bootloader files exist") != -1
    ]

    assert len(bootloader_stat_tasks) == 1, "Should have one bootloader file check task"

    stat_task = bootloader_stat_tasks[0]
    assert "ansible.builtin.stat" in stat_task, "Should use stat module"
    assert "loop" in stat_task, "Should check multiple files"

    # Verify it checks for shimx64.efi and grubx64.efi
    loop_items = stat_task.get("loop", [])
    assert any(
        "shimx64.efi" in str(item) for item in loop_items
    ), "Should check shimx64.efi"
    assert any(
        "grubx64.efi" in str(item) for item in loop_items
    ), "Should check grubx64.efi"


def test_bootloader_verification_uses_rpm() -> None:
    """Test that bootloader verification uses rpm -V for Fedora/RHEL."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks = yaml.safe_load(f)

    # Find the rpm verification task
    rpm_verify_tasks = [
        task
        for task in tasks
        if isinstance(task, dict)
        and task.get("name", "").lower().find("verify bootloader packages") != -1
    ]

    assert len(rpm_verify_tasks) == 1, "Should have one rpm verification task"

    verify_task = rpm_verify_tasks[0]
    assert "ansible.builtin.command" in verify_task, "Should use command module"

    cmd = verify_task["ansible.builtin.command"].get("cmd", "")
    assert "rpm -V" in cmd, "Should use rpm -V to verify packages"
    assert "shim-x64" in cmd, "Should verify shim-x64 package"
    assert "grub2-efi-x64" in cmd, "Should verify grub2-efi-x64 package"


def test_bootloader_warning_mentions_acer() -> None:
    """Test that bootloader warning includes Acer-specific instructions."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks = yaml.safe_load(f)

    # Find the warning task
    warning_tasks = [
        task
        for task in tasks
        if isinstance(task, dict)
        and task.get("name", "").lower().find("warn if bootloader") != -1
    ]

    assert len(warning_tasks) == 1, "Should have one bootloader warning task"

    warning_task = warning_tasks[0]
    assert "ansible.builtin.debug" in warning_task, "Should use debug module for warning"

    msg = warning_task["ansible.builtin.debug"].get("msg", "")
    assert "Acer" in msg or "Insyde" in msg, "Should mention Acer/Insyde BIOS requirement"
    assert "shimx64.efi" in msg, "Should mention shimx64.efi"
    assert (
        "trust" in msg.lower() or "trusted" in msg.lower()
    ), "Should mention manual trust requirement"


def test_bootloader_tasks_conditional_on_redhat() -> None:
    """Test that bootloader verification is conditional on RedHat/Fedora."""
    with open("roles/acer_battery/tasks/main.yml", "r") as f:
        tasks = yaml.safe_load(f)

    # Find bootloader-related tasks
    bootloader_tasks = [
        task
        for task in tasks
        if isinstance(task, dict)
        and "name" in task
        and (
            "bootloader files exist" in task["name"].lower()
            or "verify bootloader packages" in task["name"].lower()
            or "warn if bootloader" in task["name"].lower()
        )
    ]

    assert len(bootloader_tasks) == 3, "Should have three bootloader-related tasks"

    # All should be conditional on RedHat/Fedora
    for task in bootloader_tasks:
        when_clause = task.get("when", [])
        if isinstance(when_clause, str):
            when_clause = [when_clause]

        # Should have RedHat or Fedora condition
        has_os_condition = any(
            "RedHat" in str(cond) or "Fedora" in str(cond) for cond in when_clause
        )
        assert (
            has_os_condition
        ), f"Task '{task['name']}' should be conditional on RedHat/Fedora"


def test_documentation_explains_when_to_retrust() -> None:
    """Test that README documents when manual bootloader re-trust is needed."""
    with open("README.md", "r") as f:
        readme = f.read()

    # Should have a section explaining when re-trust is needed
    assert "re-trust" in readme.lower() or "retrust" in readme.lower(), (
        "README should explain when to re-trust the bootloader"
    )

    # Should mention BIOS updates require re-trust
    assert "BIOS" in readme and "update" in readme.lower(), (
        "README should mention BIOS updates require re-trust"
    )

    # Should clarify that kernel updates do NOT require re-trust
    assert "kernel updates" in readme.lower(), (
        "README should mention kernel updates"
    )

    # Should have a table or clear explanation
    assert (
        "| Event |" in readme or "requires re-trust" in readme.lower()
    ), "README should have clear guidance on re-trust requirements"

    # Should clarify MOK vs bootloader are separate
    assert "MOK" in readme and "bootloader" in readme.lower(), (
        "README should distinguish MOK enrollment from bootloader trust"
    )
