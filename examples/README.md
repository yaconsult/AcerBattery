# Example scripts (standalone)

These scripts are designed to work with Frederik Himpe's upstream driver:

https://github.com/frederik-h/acer-wmi-battery

You do **not** need to use the Ansible role from this repository to use these scripts.

## Quickstart

### Option A: run directly from the `examples/` folder

From the repository root:

```bash
chmod +x examples/*.sh

# One-shot status dump of battery/power/temps
bash examples/battery_full_status.sh

# Read temperature with sysfs node auto-discovery
bash examples/battery_temperature.sh

# Toggle charge limit with sysfs node auto-discovery
sudo bash examples/charge_limit_on.sh
sudo bash examples/charge_limit_off.sh
```

### Option B: install into your PATH

Recommended approach (keep the scripts together so helper dependencies keep working):

```bash
mkdir -p ~/.local/lib/acer-battery-examples
cp -a ./*.sh ~/.local/lib/acer-battery-examples/
chmod +x ~/.local/lib/acer-battery-examples/*.sh

mkdir -p ~/.local/bin
ln -sf ~/.local/lib/acer-battery-examples/* ~/.local/bin/
```

After that, you can run (examples):

```bash
battery_full_status.sh
battery_temperature.sh
sudo charge_limit_on.sh
sudo charge_full_then_limit_and_shutdown.sh --no-shutdown
```

Note: scripts that depend on helper scripts (for example `charge_limit_on.sh` calling
`find_health_mode_node.sh`) assume the helpers live in the same directory. The symlink-based approach above
preserves that.

## Prerequisites

- The upstream kernel module is installed.
- The module is loaded (e.g. `sudo modprobe acer_wmi_battery`).
- The expected sysfs nodes exist.

These scripts read from two places:

- `/sys/class/power_supply/*` (generic Linux power-supply interface)
- `/sys/bus/wmi/drivers/acer-wmi-battery/*` (acer-wmi-battery driver interface)

## Example script dependencies

Some scripts are standalone, while others intentionally call the small `find_*_node.sh` helpers to
auto-detect the correct sysfs path on your system.

In general, you do **not** need to add these scripts to your `PATH`. The scripts that call helpers resolve them
relative to their own directory, so running them from the repository root works as documented. If you copy or
install individual scripts elsewhere, keep the corresponding helper scripts in the same directory.

- **Standalone helpers (safe to run directly)**
  - `find_health_mode_node.sh` (prints a `health_mode` sysfs path)
  - `find_temperature_node.sh` (prints a `temperature` sysfs path)
  - `find_calibration_mode_node.sh` (prints a `calibration_mode` sysfs path)

- **Scripts that depend on helper(s)**
  - `charge_limit_on.sh` and `charge_limit_off.sh`
    - Call `find_health_mode_node.sh`
  - `battery_temperature.sh`
    - Calls `find_temperature_node.sh`
  - `calibration_mode.sh`
    - Calls `find_calibration_mode_node.sh`

- **Scripts that are standalone but can use helpers opportunistically**
  - `charge_full_then_limit_and_shutdown.sh`
    - Runs without helpers, but will display temperature if `find_temperature_node.sh` is present
  - `battery_full_status.sh`
    - Runs without helpers, but will include acer-wmi-battery temperature if `find_temperature_node.sh` is present

If you copy scripts to another machine, copy these together:

- **Charge limit toggles**
  - `charge_limit_on.sh`
  - `charge_limit_off.sh`
  - `find_health_mode_node.sh`

- **Temperature reader**
  - `battery_temperature.sh`
  - `find_temperature_node.sh`

## Which examples require sudo?

Some example scripts write to sysfs nodes (or invoke `shutdown`) and therefore must be run with `sudo`.

- **Requires sudo (writes / privileged actions)**
  - `charge_limit_on.sh` (writes `health_mode=1`)
  - `charge_limit_off.sh` (writes `health_mode=0`)
  - `calibration_mode.sh` (writes `calibration_mode`)
  - `charge_full_then_limit_and_shutdown.sh` (writes `health_mode` and may run `shutdown`)

- **No sudo required (read-only)**
  - `find_health_mode_node.sh`
  - `find_temperature_node.sh`
  - `battery_temperature.sh`
  - `battery_full_status.sh`

## ETA / time-to-full / time-to-empty

Some kernels expose:

- `time_to_full_now` (seconds)
- `time_to_empty_now` (seconds)

When present, `battery_full_status.sh` prints them and `charge_full_then_limit_and_shutdown.sh` shows an ETA during
polling. If those fields are not present, the scripts will fall back to a derived estimate when enough power/energy
(or current/charge) fields are available.

## Calibration mode

The upstream driver exposes a `calibration_mode` sysfs control. Its purpose is to help recalibrate / improve the
battery capacity reporting. In practice, this is mainly useful when battery percentage or reported full capacity is
inaccurate.

Calibration can take a long time and may affect charge/discharge behavior while running.

Recommended guidelines:

- Prefer running on AC power.
- Monitor temperature and power state while it is running.
- Make sure you know how to stop it.

This repo provides two helpers:

- `find_calibration_mode_node.sh` prints a usable sysfs path for `calibration_mode`.
- `calibration_mode.sh` provides a safer interface:
  - `status` (read current value)
  - `start` (writes `1`, asks for confirmation unless `--yes` is passed)
  - `stop` (writes `0`)

Examples:

```bash
# Show current calibration mode state
bash calibration_mode.sh status

# Start (interactive confirmation)
sudo bash calibration_mode.sh start

# Start non-interactively (for automation)
sudo bash calibration_mode.sh start --yes

# Stop
sudo bash calibration_mode.sh stop
```

For the authoritative calibration procedure and caveats, see upstream:

https://github.com/frederik-h/acer-wmi-battery#calibration-mode

## Example output (will vary by hardware/kernel)

`battery_full_status.sh`:

```text
Battery full status

[acer-wmi-battery]
health_mode: 1
calibration_mode: 0
temperature: 35.4°C (35400 m°C)

[BAT0]
type: Battery
status: Charging
capacity: 72%
voltage_now: 11.412 V
current_now: 1.216 A
power_now: 13.871 W
time_to_full_now: 00h45m (2700s)
energy_full: 46.120 Wh
energy_full_design: 57.200 Wh
full_vs_design: 80.6%
```

`charge_full_then_limit_and_shutdown.sh`:

```text
Battery capacity source: /sys/class/power_supply/BAT0/capacity
AC online source: /sys/class/power_supply/AC/online
Disabling charge limit (health_mode=0) until 100%...
Current charge: 72% (temp:35.4°C I:1.216A V:11.412V P:13.871W ETA_to_full:00h45m)
Current charge: 73% (temp:35.7°C I:1.108A V:11.425V P:12.662W ETA_to_full:00h43m)
...
Reached target (100%). Enabling charge limit (health_mode=1).
Done (shutdown skipped).
```

## battery_full_status.sh (full battery + power status report)

This script will attempt to show (when your hardware/kernel exposes it):

- Battery state (`BAT*`): `status`, `capacity`, voltage/current/power, ETA fields
- Battery capacity vs design/theoretical:
  - `energy_full` vs `energy_full_design` (Wh), or
  - `charge_full` vs `charge_full_design` (Ah)
- AC adapter state (`AC*` / `ADP*`): typically an `online` indicator
- USB-C / Power Delivery state (`ucsi-source-psy-*`): USB-C PD power-source nodes from the kernel UCSI stack
- acer-wmi-battery: `health_mode`, `calibration_mode`, and battery `temperature` (if present)

Note: entries like `ucsi-source-psy-usbc000:001` do not necessarily mean the battery is charging over USB-C.
They represent a USB-C/PD power source object. To confirm whether it is actively supplying power, check its
`online` field and compare with your battery `status`.

To dump all readable attributes for detected `BAT*`/`AC*`/`ADP*`/UCSI nodes:

```bash
bash battery_full_status.sh --all
```

## charge_full_then_limit_and_shutdown.sh (charge to target, then limit + optional shutdown)

Some users prefer to temporarily allow charging to 100% (for calibration/travel), then re-enable the 80% limit and
shut down automatically. A simple approach is:

1. Set `health_mode` to `0` (unlimited)
2. Poll battery capacity periodically
3. When capacity reaches your target, set `health_mode` to `1` and optionally run `shutdown`

This repository includes a ready-to-use example script:

```bash
sudo bash charge_full_then_limit_and_shutdown.sh
```

Useful options:

```bash
# Poll every 60 seconds
sudo bash charge_full_then_limit_and_shutdown.sh --interval 60

# Charge only to 95%, then re-enable the limit and shut down
sudo bash charge_full_then_limit_and_shutdown.sh --target 95

# Do not shut down at the end
sudo bash charge_full_then_limit_and_shutdown.sh --no-shutdown

# Allow running even if AC adapter is not detected
sudo bash charge_full_then_limit_and_shutdown.sh --allow-on-battery

# Dry-run (print actions without changing health_mode or shutting down)
sudo bash charge_full_then_limit_and_shutdown.sh --dry-run
```
