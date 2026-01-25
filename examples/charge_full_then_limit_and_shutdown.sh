#!/usr/bin/env bash

set -euo pipefail

HEALTH_MODE_PATH="/sys/bus/wmi/drivers/acer-wmi-battery/health_mode"

SLEEP_INTERVAL_SECONDS=150
TARGET_PERCENT=100
SHUTDOWN=1

usage() {
  cat <<'USAGE'
Usage: charge_full_then_limit_and_shutdown.sh [--interval SECONDS] [--target PERCENT] [--no-shutdown] [--help]

Purpose:
- Temporarily disable the 80% charge limit (health_mode=0)
- Wait until battery reaches target percent (default: 100)
- Re-enable the 80% charge limit (health_mode=1)
- Shut down the machine (optional)

Options:
  --interval SECONDS   Poll interval (default: 150)
  --target PERCENT     Target percentage (default: 100)
  --no-shutdown        Do not shut down at the end
  --help               Show this help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --interval)
      SLEEP_INTERVAL_SECONDS="$2"; shift 2 ;;
    --target)
      TARGET_PERCENT="$2"; shift 2 ;;
    --no-shutdown)
      SHUTDOWN=0; shift 1 ;;
    --help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

find_battery_capacity_path() {
  local cap
  for cap in /sys/class/power_supply/BAT*/capacity; do
    if [ -f "$cap" ]; then
      echo "$cap"
      return 0
    fi
  done
  return 1
}

find_ac_online_path() {
  local online
  for online in /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online; do
    if [ -f "$online" ]; then
      echo "$online"
      return 0
    fi
  done
  return 1
}

require_module_interface() {
  if [ -f "$HEALTH_MODE_PATH" ]; then
    return 0
  fi

  if command -v modprobe >/dev/null 2>&1; then
    sudo modprobe acer_wmi_battery || true
  fi

  if [ ! -f "$HEALTH_MODE_PATH" ]; then
    echo "Cannot find $HEALTH_MODE_PATH (module not loaded or unsupported system)" >&2
    exit 1
  fi
}

read_int_file() {
  local path="$1"
  local val
  val=$(cat "$path" 2>/dev/null || true)
  if ! [[ "$val" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  echo "$val"
}

set_health_mode() {
  local mode="$1"
  echo "$mode" | sudo tee "$HEALTH_MODE_PATH" >/dev/null
}

require_module_interface

CAPACITY_PATH=$(find_battery_capacity_path) || {
  echo "Could not find battery capacity at /sys/class/power_supply/BAT*/capacity" >&2
  exit 1
}

AC_ONLINE_PATH=$(find_ac_online_path || true)
if [ -n "${AC_ONLINE_PATH:-}" ]; then
  if [ "$(read_int_file "$AC_ONLINE_PATH" || echo 0)" -eq 0 ]; then
    echo "AC does not appear to be connected (based on $AC_ONLINE_PATH). Aborting." >&2
    exit 1
  fi
fi

CURRENT=$(read_int_file "$CAPACITY_PATH") || {
  echo "Could not read battery percentage from $CAPACITY_PATH" >&2
  exit 1
}

echo "Battery capacity source: $CAPACITY_PATH"
[ -n "${AC_ONLINE_PATH:-}" ] && echo "AC online source: $AC_ONLINE_PATH"

echo "Disabling charge limit (health_mode=0) until ${TARGET_PERCENT}%..."
set_health_mode 0

while true; do
  CURRENT=$(read_int_file "$CAPACITY_PATH" || true)
  if [ -z "${CURRENT:-}" ]; then
    echo "Could not read battery percentage; retrying in ${SLEEP_INTERVAL_SECONDS}s..." >&2
    sleep "$SLEEP_INTERVAL_SECONDS"
    continue
  fi

  echo "Current charge: ${CURRENT}%"

  if [ "$CURRENT" -ge "$TARGET_PERCENT" ]; then
    echo "Reached target (${TARGET_PERCENT}%). Enabling charge limit (health_mode=1)."
    set_health_mode 1

    if [ "$SHUTDOWN" -eq 1 ]; then
      echo "Shutting down now."
      sudo shutdown now
    else
      echo "Done (shutdown skipped)."
    fi

    exit 0
  fi

  sleep "$SLEEP_INTERVAL_SECONDS"
done
