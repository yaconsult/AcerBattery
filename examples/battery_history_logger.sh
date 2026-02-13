#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage: battery_history_logger.sh [--interval SECONDS] [--output FILE] [--battery BATX] [--format csv|tsv]

Logs battery metrics periodically to a file for later analysis.

Fields:
- timestamp
- battery_name
- status
- capacity_percent
- voltage_now_uv
- current_now_ua
- power_now_uw
- eta_label
- eta_hhmm
- temperature_mdegc

Notes:
- Read-only: does not require sudo.
- ETA uses time_to_full_now/time_to_empty_now when present and falls back to a derived estimate.
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

interval=30
output=""
battery=""
format="csv"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)
      interval="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
      shift 2
      ;;
    --battery)
      battery="${2:-}"
      shift 2
      ;;
    --format)
      format="${2:-}"
      shift 2
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

if [[ "$format" != "csv" && "$format" != "tsv" ]]; then
  echo "Invalid --format: $format (expected csv or tsv)" >&2
  exit 2
fi

sep="," 
if [[ "$format" == "tsv" ]]; then
  sep=$'\t'
fi

write_row() {
  local ts="$1" bat_name="$2" status="$3" capacity="$4" voltage_raw="$5" current_raw="$6" power_raw="$7" eta_label="$8" eta_hhmm="$9" temp_raw="${10}"
  printf "%s" "$ts" >>"$output"
  printf "%s%s" "$sep" "$bat_name" >>"$output"
  printf "%s%s" "$sep" "$status" >>"$output"
  printf "%s%s" "$sep" "$capacity" >>"$output"
  printf "%s%s" "$sep" "$voltage_raw" >>"$output"
  printf "%s%s" "$sep" "$current_raw" >>"$output"
  printf "%s%s" "$sep" "$power_raw" >>"$output"
  printf "%s%s" "$sep" "$eta_label" >>"$output"
  printf "%s%s" "$sep" "$eta_hhmm" >>"$output"
  printf "%s%s" "$sep" "$temp_raw" >>"$output"
  printf "\n" >>"$output"
}

bat_dir="$(find_battery_dir "$battery" || true)"
if [[ -z "${bat_dir:-}" ]]; then
  echo "Could not find a BAT* power_supply device under /sys/class/power_supply" >&2
  exit 1
fi

bat_name="$(basename "$bat_dir")"

temp_node="$(find_temp_node)"

if [[ -z "${output:-}" ]]; then
  output="battery_history_${bat_name}.csv"
  if [[ "$format" == "tsv" ]]; then
    output="battery_history_${bat_name}.tsv"
  fi
fi

if [[ ! -f "$output" ]]; then
  : >"$output"
  write_row \
    "timestamp" \
    "battery_name" \
    "status" \
    "capacity_percent" \
    "voltage_now_uv" \
    "current_now_ua" \
    "power_now_uw" \
    "eta_label" \
    "eta_hhmm" \
    "temperature_mdegc"
fi

while true; do
  ts="$(date -Is)"

  status="$(cat "$bat_dir/status" 2>/dev/null || true)"
  capacity="$(read_num_file "$bat_dir/capacity" || true)"

  voltage_raw="$(read_num_file "$bat_dir/voltage_now" || true)"
  current_raw="$(read_num_file "$bat_dir/current_now" || true)"
  power_raw="$(read_num_file "$bat_dir/power_now" || true)"

  ttf_raw="$(read_num_file "$bat_dir/time_to_full_now" || true)"
  tte_raw="$(read_num_file "$bat_dir/time_to_empty_now" || true)"

  energy_now_raw="$(read_num_file "$bat_dir/energy_now" || true)"
  energy_full_raw="$(read_num_file "$bat_dir/energy_full" || true)"
  charge_now_raw="$(read_num_file "$bat_dir/charge_now" || true)"
  charge_full_raw="$(read_num_file "$bat_dir/charge_full" || true)"

  eta_label=""
  eta_hhmm=""

  if [[ "$status" == "Charging" && -n "${ttf_raw:-}" && "$ttf_raw" -gt 0 ]] 2>/dev/null; then
    eta_label="ETA_to_full"
    eta_hhmm="$(fmt_seconds_hhmm "$ttf_raw")"
  elif [[ "$status" == "Discharging" && -n "${tte_raw:-}" && "$tte_raw" -gt 0 ]] 2>/dev/null; then
    eta_label="ETA_to_empty"
    eta_hhmm="$(fmt_seconds_hhmm "$tte_raw")"
  else
    eta_seconds="$(estimate_eta_seconds "$status" "$energy_now_raw" "$energy_full_raw" "$power_raw" "$charge_now_raw" "$charge_full_raw" "$current_raw" 2>/dev/null || true)"
    if [[ -n "${eta_seconds:-}" ]]; then
      if [[ "$status" == "Charging" ]]; then
        eta_label="ETA_to_full_est"
      elif [[ "$status" == "Discharging" ]]; then
        eta_label="ETA_to_empty_est"
      else
        eta_label="ETA_est"
      fi
      eta_hhmm="$(fmt_seconds_hhmm "$eta_seconds")"
    fi
  fi

  temp_raw=""
  if [[ -n "${temp_node:-}" && -f "$temp_node" ]]; then
    temp_raw="$(read_num_file "$temp_node" || true)"
  fi

  write_row \
    "$ts" \
    "$bat_name" \
    "${status//$'\n'/}" \
    "${capacity:-}" \
    "${voltage_raw:-}" \
    "${current_raw:-}" \
    "${power_raw:-}" \
    "${eta_label:-}" \
    "${eta_hhmm:-}" \
    "${temp_raw:-}"

  sleep "$interval"
done
