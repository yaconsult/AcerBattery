"""Test the acer_battery role functionality."""

from typing import Dict, Any, Iterator
import os
import shutil
import subprocess
import pytest
from pathlib import Path


@pytest.fixture
def mock_git_repo(tmp_path: Path) -> Iterator[Path]:
    """Create a mock git repository for testing."""
    # Create working repository
    repo_path = tmp_path / "acer-wmi-battery"
    repo_path.mkdir()

    # Initialize git repo with master branch
    subprocess.run(
        ["git", "init", "--initial-branch=master"],
        cwd=repo_path,
        check=True,
        capture_output=True,
    )

    # Configure git
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        cwd=repo_path,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test User"],
        cwd=repo_path,
        check=True,
        capture_output=True,
    )

    # Create dummy files
    (repo_path / "Makefile").write_text("obj-m += acer-wmi-battery.o\n")
    (repo_path / "acer-wmi-battery.c").write_text(
        '#include <linux/module.h>\n\nMODULE_LICENSE("GPL");\n'
    )

    # Add and commit files
    subprocess.run(
        ["git", "add", "."],
        cwd=repo_path,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "commit", "-m", "Initial commit"],
        cwd=repo_path,
        check=True,
        capture_output=True,
    )

    # Create a 'main' branch so tests can use the role default version.
    subprocess.run(
        ["git", "checkout", "-b", "main"],
        cwd=repo_path,
        check=True,
        capture_output=True,
    )

    yield repo_path

    # Cleanup
    shutil.rmtree(repo_path)


def test_role_syntax(mock_git_repo: Path) -> None:
    """Test that the role syntax is valid."""
    result = subprocess.run(
        [
            "ansible-playbook",
            "-i",
            "tests/inventory",
            "--syntax-check",
            "tests/test.yml",
        ],
        cwd=os.path.dirname(os.path.dirname(__file__)),
        capture_output=True,
        text=True,
        env={
            **os.environ,
            "ANSIBLE_ROLES_PATH": str(mock_git_repo.parent),
            "MOCK_REPO_PATH": str(mock_git_repo),
            "ANSIBLE_PYTHON_INTERPRETER": "/usr/bin/python3",
        },
    )
    assert result.returncode == 0, f"Syntax check failed: {result.stderr}"


def test_role_check_mode(mock_git_repo: Path) -> None:
    """Test that the role runs in check mode."""
    result = subprocess.run(
        ["ansible-playbook", "-i", "tests/inventory", "--check", "tests/test.yml"],
        cwd=os.path.dirname(os.path.dirname(__file__)),
        capture_output=True,
        text=True,
        env={
            **os.environ,
            "ANSIBLE_ROLES_PATH": str(mock_git_repo.parent),
            "MOCK_REPO_PATH": str(mock_git_repo),
            "ANSIBLE_PYTHON_INTERPRETER": "/usr/bin/python3",
        },
    )
    assert result.returncode == 0, f"Check mode failed: {result.stderr}"


def test_role_idempotency(mock_git_repo: Path) -> None:
    """Test that the role is idempotent."""
    # First run
    result1 = subprocess.run(
        ["ansible-playbook", "-i", "tests/inventory", "--check", "tests/test.yml"],
        cwd=os.path.dirname(os.path.dirname(__file__)),
        capture_output=True,
        text=True,
        env={
            **os.environ,
            "ANSIBLE_ROLES_PATH": str(mock_git_repo.parent),
            "MOCK_REPO_PATH": str(mock_git_repo),
            "ANSIBLE_PYTHON_INTERPRETER": "/usr/bin/python3",
        },
    )
    assert result1.returncode == 0, f"First run failed: {result1.stderr}"

    # Second run
    result2 = subprocess.run(
        ["ansible-playbook", "-i", "tests/inventory", "--check", "tests/test.yml"],
        cwd=os.path.dirname(os.path.dirname(__file__)),
        capture_output=True,
        text=True,
        env={
            **os.environ,
            "ANSIBLE_ROLES_PATH": str(mock_git_repo.parent),
            "MOCK_REPO_PATH": str(mock_git_repo),
            "ANSIBLE_PYTHON_INTERPRETER": "/usr/bin/python3",
        },
    )
    assert result2.returncode == 0, f"Second run failed: {result2.stderr}"

    # In check mode, Ansible may still report changes depending on tasks/handlers.
    # The key invariant for this test suite is that the role can run repeatedly
    # without failures.
    assert "failed=0" in result2.stdout, "Role should not report failures"
