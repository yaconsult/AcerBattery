#!/usr/bin/env bash

set -euo pipefail

HEALTH_MODE_PATH="/sys/bus/wmi/drivers/acer-wmi-battery/health_mode"

SLEEP_INTERVAL_SECONDS=150
TARGET_PERCENT=100
SHUTDOWN=1
ALLOW_ON_BATTERY=0
DRY_RUN=0

DID_DISABLE_LIMIT=0

usage() {
  cat <<'USAGE'
Usage: charge_full_then_limit_and_shutdown.sh [--interval SECONDS] [--target PERCENT] [--no-shutdown] [--allow-on-battery] [--dry-run] [--help]

Purpose:
- Temporarily disable the 80% charge limit (health_mode=0)
- Wait until battery reaches target percent (default: 100)
- Re-enable the 80% charge limit (health_mode=1)
- Shut down the machine (optional)

Options:
  --interval SECONDS   Poll interval (default: 150)
  --target PERCENT     Target percentage (default: 100)
  --no-shutdown        Do not shut down at the end
  --allow-on-battery   Allow running without AC connected
  --dry-run            Print actions without changing health_mode or shutting down
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
    --allow-on-battery)
      ALLOW_ON_BATTERY=1; shift 1 ;;
    --dry-run)
      DRY_RUN=1; shift 1 ;;
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

read_num_file() {
  local path="$1"
  local val
  val=$(cat "$path" 2>/dev/null || true)
  if ! [[ "$val" =~ ^-?[0-9]+$ ]]; then
    return 1
  fi
  echo "$val"
}

fmt_uv() {
  local v="$1"
  awk -v x="$v" 'BEGIN { printf "%.3fV", x/1000000 }'
}

fmt_ua() {
  local v="$1"
  awk -v x="$v" 'BEGIN { printf "%.3fA", x/1000000 }'
}

fmt_uw() {
  local v="$1"
  awk -v x="$v" 'BEGIN { printf "%.3fW", x/1000000 }'
}

fmt_seconds_hhmm() {
  local s="$1"
  awk -v x="$s" 'BEGIN {
    if (x < 0) { x = -x }
    h = int(x/3600)
    m = int((x - h*3600)/60)
    printf "%02dh%02dm", h, m
  }'
}

estimate_eta_seconds() {
  local status="$1"
  local energy_now="$2"
  local energy_full="$3"
  local power_now="$4"
  local charge_now="$5"
  local charge_full="$6"
  local current_now="$7"

  if [[ "$status" == "Charging" ]]; then
    if [[ -n "${energy_now:-}" && -n "${energy_full:-}" && -n "${power_now:-}" && "$power_now" != "0" ]]; then
      awk -v en="$energy_now" -v ef="$energy_full" -v pw="$power_now" 'BEGIN {
        rem = ef - en
        if (rem < 0) rem = 0
        if (pw == 0) { exit 1 }
        printf "%d", int((rem / pw) * 3600)
      }'
      return 0
    fi

    if [[ -n "${charge_now:-}" && -n "${charge_full:-}" && -n "${current_now:-}" && "$current_now" != "0" ]]; then
      awk -v cn="$charge_now" -v cf="$charge_full" -v cur="$current_now" 'BEGIN {
        rem = cf - cn
        if (rem < 0) rem = 0
        if (cur == 0) { exit 1 }
        printf "%d", int((rem / cur) * 3600)
      }'
      return 0
    fi
  fi

  if [[ "$status" == "Discharging" ]]; then
    if [[ -n "${energy_now:-}" && -n "${power_now:-}" && "$power_now" != "0" ]]; then
      awk -v en="$energy_now" -v pw="$power_now" 'BEGIN {
        if (en < 0) en = 0
        if (pw == 0) { exit 1 }
        printf "%d", int((en / pw) * 3600)
      }'
      return 0
    fi

    if [[ -n "${charge_now:-}" && -n "${current_now:-}" && "$current_now" != "0" ]]; then
      awk -v cn="$charge_now" -v cur="$current_now" 'BEGIN {
        if (cn < 0) cn = 0
        if (cur == 0) { exit 1 }
        printf "%d", int((cn / cur) * 3600)
      }'
      return 0
    fi
  fi

  return 1
}

read_temp_c() {
  local path="$1"
  local val
  val=$(cat "$path" 2>/dev/null || true)
  if ! [[ "$val" =~ ^-?[0-9]+$ ]]; then
    return 1
  fi
  awk -v v="$val" 'BEGIN { printf "%.1f°C", v/1000 }'
}

set_health_mode() {
  local mode="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: would set health_mode=${mode}"
    return 0
  fi
  echo "$mode" | sudo tee "$HEALTH_MODE_PATH" >/dev/null
}

cleanup() {
  # Safety: if we disabled the charge limit during this run, try to restore it.
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi
  if [ "$DID_DISABLE_LIMIT" -eq 1 ]; then
    echo "Restoring charge limit (health_mode=1)"
    echo 1 | sudo tee "$HEALTH_MODE_PATH" >/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

require_module_interface

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMP_PATH=""
if [ -f "${script_dir}/find_temperature_node.sh" ]; then
  TEMP_PATH="$(bash "${script_dir}/find_temperature_node.sh" 2>/dev/null || true)"
fi
if [ -n "${TEMP_PATH:-}" ] && [ ! -f "$TEMP_PATH" ]; then
  TEMP_PATH=""
fi

CAPACITY_PATH=$(find_battery_capacity_path) || {
  echo "Could not find battery capacity at /sys/class/power_supply/BAT*/capacity" >&2
  exit 1
}

BATTERY_DIR="$(dirname "$CAPACITY_PATH")"
CURRENT_NOW_PATH="${BATTERY_DIR}/current_now"
VOLTAGE_NOW_PATH="${BATTERY_DIR}/voltage_now"
POWER_NOW_PATH="${BATTERY_DIR}/power_now"
STATUS_PATH="${BATTERY_DIR}/status"
ENERGY_NOW_PATH="${BATTERY_DIR}/energy_now"
ENERGY_FULL_PATH="${BATTERY_DIR}/energy_full"
CHARGE_NOW_PATH="${BATTERY_DIR}/charge_now"
CHARGE_FULL_PATH="${BATTERY_DIR}/charge_full"
TIME_TO_FULL_NOW_PATH="${BATTERY_DIR}/time_to_full_now"
TIME_TO_EMPTY_NOW_PATH="${BATTERY_DIR}/time_to_empty_now"

AC_ONLINE_PATH=$(find_ac_online_path || true)
if [ -n "${AC_ONLINE_PATH:-}" ]; then
  if [ "$(read_int_file "$AC_ONLINE_PATH" || echo 0)" -eq 0 ]; then
    if [ "$ALLOW_ON_BATTERY" -eq 1 ]; then
      echo "Warning: AC does not appear to be connected (based on $AC_ONLINE_PATH). Continuing due to --allow-on-battery." >&2
    else
      echo "AC does not appear to be connected (based on $AC_ONLINE_PATH). Aborting." >&2
      exit 1
    fi
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
DID_DISABLE_LIMIT=1

while true; do
  CURRENT=$(read_int_file "$CAPACITY_PATH" || true)
  if [ -z "${CURRENT:-}" ]; then
    echo "Could not read battery percentage; retrying in ${SLEEP_INTERVAL_SECONDS}s..." >&2
    sleep "$SLEEP_INTERVAL_SECONDS"
    continue
  fi

  TEMP_DISPLAY=""
  if [ -n "${TEMP_PATH:-}" ]; then
    TEMP_DISPLAY=$(read_temp_c "$TEMP_PATH" 2>/dev/null || true)
  fi

  CURRENT_NOW_DISPLAY=""
  VOLTAGE_NOW_DISPLAY=""
  POWER_NOW_DISPLAY=""
  ETA_DISPLAY=""
  ETA_LABEL=""

  if [ -f "$CURRENT_NOW_PATH" ]; then
    CURRENT_NOW_RAW=$(read_num_file "$CURRENT_NOW_PATH" 2>/dev/null || true)
    if [ -n "${CURRENT_NOW_RAW:-}" ]; then
      CURRENT_NOW_DISPLAY="$(fmt_ua "$CURRENT_NOW_RAW")"
    fi
  fi

  if [ -f "$VOLTAGE_NOW_PATH" ]; then
    VOLTAGE_NOW_RAW=$(read_num_file "$VOLTAGE_NOW_PATH" 2>/dev/null || true)
    if [ -n "${VOLTAGE_NOW_RAW:-}" ]; then
      VOLTAGE_NOW_DISPLAY="$(fmt_uv "$VOLTAGE_NOW_RAW")"
    fi
  fi

  if [ -f "$POWER_NOW_PATH" ]; then
    POWER_NOW_RAW=$(read_num_file "$POWER_NOW_PATH" 2>/dev/null || true)
    if [ -n "${POWER_NOW_RAW:-}" ]; then
      POWER_NOW_DISPLAY="$(fmt_uw "$POWER_NOW_RAW")"
    fi
  fi

  STATUS_VAL=""
  if [ -f "$STATUS_PATH" ]; then
    STATUS_VAL=$(cat "$STATUS_PATH" 2>/dev/null || true)
  fi

  if [ "$STATUS_VAL" = "Charging" ] && [ -f "$TIME_TO_FULL_NOW_PATH" ]; then
    TTF_RAW=$(read_num_file "$TIME_TO_FULL_NOW_PATH" 2>/dev/null || true)
    if [ -n "${TTF_RAW:-}" ] && [ "$TTF_RAW" -gt 0 ] 2>/dev/null; then
      ETA_DISPLAY="$(fmt_seconds_hhmm "$TTF_RAW")"
      ETA_LABEL="ETA_to_full"
    fi
  fi

  if [ -z "${ETA_DISPLAY:-}" ] && [ "$STATUS_VAL" = "Discharging" ] && [ -f "$TIME_TO_EMPTY_NOW_PATH" ]; then
    TTE_RAW=$(read_num_file "$TIME_TO_EMPTY_NOW_PATH" 2>/dev/null || true)
    if [ -n "${TTE_RAW:-}" ] && [ "$TTE_RAW" -gt 0 ] 2>/dev/null; then
      ETA_DISPLAY="$(fmt_seconds_hhmm "$TTE_RAW")"
      ETA_LABEL="ETA_to_empty"
    fi
  fi

  if [ -z "${ETA_DISPLAY:-}" ]; then
    ENERGY_NOW_RAW=""
    ENERGY_FULL_RAW=""
    CHARGE_NOW_RAW=""
    CHARGE_FULL_RAW=""

    [ -f "$ENERGY_NOW_PATH" ] && ENERGY_NOW_RAW=$(read_num_file "$ENERGY_NOW_PATH" 2>/dev/null || true)
    [ -f "$ENERGY_FULL_PATH" ] && ENERGY_FULL_RAW=$(read_num_file "$ENERGY_FULL_PATH" 2>/dev/null || true)
    [ -f "$CHARGE_NOW_PATH" ] && CHARGE_NOW_RAW=$(read_num_file "$CHARGE_NOW_PATH" 2>/dev/null || true)
    [ -f "$CHARGE_FULL_PATH" ] && CHARGE_FULL_RAW=$(read_num_file "$CHARGE_FULL_PATH" 2>/dev/null || true)

    ETA_SECONDS=$(estimate_eta_seconds "$STATUS_VAL" "$ENERGY_NOW_RAW" "$ENERGY_FULL_RAW" "$POWER_NOW_RAW" "$CHARGE_NOW_RAW" "$CHARGE_FULL_RAW" "$CURRENT_NOW_RAW" 2>/dev/null || true)
    if [ -n "${ETA_SECONDS:-}" ]; then
      ETA_DISPLAY="$(fmt_seconds_hhmm "$ETA_SECONDS")"
      if [ "$STATUS_VAL" = "Charging" ]; then
        ETA_LABEL="ETA_to_full_est"
      elif [ "$STATUS_VAL" = "Discharging" ]; then
        ETA_LABEL="ETA_to_empty_est"
      fi
    fi
  fi

  EXTRA=""
  [ -n "${TEMP_DISPLAY:-}" ] && EXTRA+=" temp:${TEMP_DISPLAY}"
  [ -n "${CURRENT_NOW_DISPLAY:-}" ] && EXTRA+=" I:${CURRENT_NOW_DISPLAY}"
  [ -n "${VOLTAGE_NOW_DISPLAY:-}" ] && EXTRA+=" V:${VOLTAGE_NOW_DISPLAY}"
  [ -n "${POWER_NOW_DISPLAY:-}" ] && EXTRA+=" P:${POWER_NOW_DISPLAY}"
  if [ -n "${ETA_DISPLAY:-}" ]; then
    if [ -n "${ETA_LABEL:-}" ]; then
      EXTRA+=" ${ETA_LABEL}:${ETA_DISPLAY}"
    else
      EXTRA+=" ETA:${ETA_DISPLAY}"
    fi
  fi

  if [ -n "${EXTRA:-}" ]; then
    echo "Current charge: ${CURRENT}% (${EXTRA# })"
  else
    echo "Current charge: ${CURRENT}%"
  fi

  if [ "$CURRENT" -ge "$TARGET_PERCENT" ]; then
    echo "Reached target (${TARGET_PERCENT}%). Enabling charge limit (health_mode=1)."
    set_health_mode 1
    DID_DISABLE_LIMIT=0

    if [ "$SHUTDOWN" -eq 1 ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "DRY RUN: would shut down now"
        exit 0
      fi
      echo "Shutting down now."
      sudo shutdown now
    else
      echo "Done (shutdown skipped)."
    fi

    exit 0
  fi

  sleep "$SLEEP_INTERVAL_SECONDS"
done
