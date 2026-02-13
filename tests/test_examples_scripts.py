"""Tests for example scripts under examples/.

These tests focus on developer sanity checks:
- Shell syntax validation (bash -n)
- Script dependency checks (helper scripts that are invoked by other examples)

They do not attempt to validate hardware-specific sysfs behavior.
"""

from __future__ import annotations

from pathlib import Path
import subprocess


REPO_ROOT = Path(__file__).resolve().parents[1]
EXAMPLES_DIR = REPO_ROOT / "examples"


def _bash_syntax_check(path: Path) -> None:
    result = subprocess.run(
        ["bash", "-n", str(path)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"bash -n failed for {path}: {result.stderr}"


def test_examples_shell_syntax() -> None:
    scripts = sorted(EXAMPLES_DIR.glob("*.sh"))
    assert scripts, "No example scripts found under examples/*.sh"

    for script in scripts:
        _bash_syntax_check(script)


def test_example_script_dependencies_present() -> None:
    dependencies: dict[str, list[str]] = {
        "charge_limit_on.sh": ["find_health_mode_node.sh"],
        "charge_limit_off.sh": ["find_health_mode_node.sh"],
        "battery_temperature.sh": ["find_temperature_node.sh"],
        "calibration_mode.sh": ["find_calibration_mode_node.sh"],
    }

    for script_name, required in dependencies.items():
        script_path = EXAMPLES_DIR / script_name
        assert script_path.exists(), f"Expected example script missing: {script_path}"

        for helper_name in required:
            helper_path = EXAMPLES_DIR / helper_name
            assert helper_path.exists(), (
                f"Example script dependency missing: {script_name} requires {helper_name}"
            )
