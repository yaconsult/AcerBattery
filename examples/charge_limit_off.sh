#!/usr/bin/env bash
set -euo pipefail

paths=(
  "/sys/bus/wmi/drivers/acer-wmi-battery/health_mode"
  "/sys/devices/platform/acer-wmi-battery/health_mode"
)

for p in "${paths[@]}"; do
  if [[ -w "$p" ]]; then
    echo 0 | sudo tee "$p" >/dev/null
    echo "Disabled charge limit (health_mode=0) via: $p"
    exit 0
  fi
  if [[ -e "$p" ]]; then
    echo "Found but not writable: $p" >&2
  fi
done

echo "Could not find a writable health_mode sysfs node. Is the module loaded (sudo modprobe acer_wmi_battery)?" >&2
exit 1
