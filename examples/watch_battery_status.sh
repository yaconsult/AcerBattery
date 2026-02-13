#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage: watch_battery_status.sh [--interval SECONDS] [--battery BATX] [--no-clear]

Shows a refreshing battery status view using /sys/class/power_supply.
EOF
}

read_num_file() {
  local path="$1"
  local v
  v="$(cat "$path" 2>/dev/null || true)"
  v="${v//$'\n'/}"
  if [[ "$v" =~ ^-?[0-9]+$ ]]; then
    echo "$v"
  fi
}

fmt_ua() { awk -v x="$1" 'BEGIN { printf "%.3fA", x/1000000 }'; }
fmt_uv() { awk -v x="$1" 'BEGIN { printf "%.3fV", x/1000000 }'; }
fmt_uw() { awk -v x="$1" 'BEGIN { printf "%.3fW", x/1000000 }'; }
fmt_temp_mdegc() { awk -v x="$1" 'BEGIN { printf "%.1f°C", x/1000 }'; }

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

find_battery_dir() {
  local name="${1:-}"
  if [[ -n "${name:-}" && -d "/sys/class/power_supply/${name}" ]]; then
    echo "/sys/class/power_supply/${name}"
    return 0
  fi

  local d
  for d in /sys/class/power_supply/BAT*; do
    [[ -d "$d" ]] || continue
    local t
    t="$(cat "$d/type" 2>/dev/null || true)"
    if [[ "$t" == "Battery" ]]; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

find_temp_node() {
  if [[ -f "${script_dir}/find_temperature_node.sh" ]]; then
    bash "${script_dir}/find_temperature_node.sh" 2>/dev/null || true
  fi
}

interval=10
battery=""
no_clear=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)
      interval="${2:-}"
      shift 2
      ;;
    --battery)
      battery="${2:-}"
      shift 2
      ;;
    --no-clear)
      no_clear=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac

done

bat_dir="$(find_battery_dir "$battery" || true)"
if [[ -z "${bat_dir:-}" ]]; then
  echo "Could not find a BAT* power_supply device under /sys/class/power_supply" >&2
  exit 1
fi

temp_node="$(find_temp_node)"

while true; do
  if [[ "$no_clear" -eq 0 ]]; then
    clear
  fi

  now="$(date -Is)"

  capacity="$(read_num_file "$bat_dir/capacity" || true)"
  status="$(cat "$bat_dir/status" 2>/dev/null || true)"

  voltage_raw="$(read_num_file "$bat_dir/voltage_now" || true)"
  current_raw="$(read_num_file "$bat_dir/current_now" || true)"
  power_raw="$(read_num_file "$bat_dir/power_now" || true)"

  ttf_raw="$(read_num_file "$bat_dir/time_to_full_now" || true)"
  tte_raw="$(read_num_file "$bat_dir/time_to_empty_now" || true)"

  energy_now_raw="$(read_num_file "$bat_dir/energy_now" || true)"
  energy_full_raw="$(read_num_file "$bat_dir/energy_full" || true)"
  charge_now_raw="$(read_num_file "$bat_dir/charge_now" || true)"
  charge_full_raw="$(read_num_file "$bat_dir/charge_full" || true)"

  eta_display=""
  eta_label=""

  if [[ "$status" == "Charging" && -n "${ttf_raw:-}" && "$ttf_raw" -gt 0 ]] 2>/dev/null; then
    eta_display="$(fmt_seconds_hhmm "$ttf_raw")"
    eta_label="ETA_to_full"
  elif [[ "$status" == "Discharging" && -n "${tte_raw:-}" && "$tte_raw" -gt 0 ]] 2>/dev/null; then
    eta_display="$(fmt_seconds_hhmm "$tte_raw")"
    eta_label="ETA_to_empty"
  else
    eta_seconds="$(estimate_eta_seconds "$status" "$energy_now_raw" "$energy_full_raw" "$power_raw" "$charge_now_raw" "$charge_full_raw" "$current_raw" 2>/dev/null || true)"
    if [[ -n "${eta_seconds:-}" ]]; then
      eta_display="$(fmt_seconds_hhmm "$eta_seconds")"
      if [[ "$status" == "Charging" ]]; then
        eta_label="ETA_to_full_est"
      elif [[ "$status" == "Discharging" ]]; then
        eta_label="ETA_to_empty_est"
      else
        eta_label="ETA_est"
      fi
    fi
  fi

  echo "Battery watch"
  echo
  echo "time: $now"
  echo "device: $bat_dir"
  [[ -n "${status:-}" ]] && echo "status: $status"
  [[ -n "${capacity:-}" ]] && echo "capacity: ${capacity}%"

  if [[ -n "${voltage_raw:-}" ]]; then
    echo "voltage_now: $(fmt_uv "$voltage_raw")"
  fi

  if [[ -n "${current_raw:-}" ]]; then
    echo "current_now: $(fmt_ua "$current_raw")"
  fi

  if [[ -n "${power_raw:-}" ]]; then
    echo "power_now: $(fmt_uw "$power_raw")"
  fi

  if [[ -n "${eta_display:-}" ]]; then
    echo "${eta_label}: ${eta_display}"
  fi

  if [[ -n "${temp_node:-}" && -f "$temp_node" ]]; then
    temp_raw="$(read_num_file "$temp_node" || true)"
    if [[ -n "${temp_raw:-}" ]]; then
      echo "temperature: $(fmt_temp_mdegc "$temp_raw") (${temp_raw} m°C)"
      echo "temperature_node: $temp_node"
    fi
  fi

  sleep "$interval"
done
