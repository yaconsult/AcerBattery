#!/usr/bin/env bash
set -euo pipefail

SHOW_ALL=0

usage() {
  cat <<'USAGE'
Usage: battery_full_status.sh [--all] [--help]

Purpose:
- Display comprehensive battery and charging information from:
  - /sys/class/power_supply (BAT*/AC*/ADP*)
  - acer-wmi-battery sysfs nodes (health_mode, calibration_mode, temperature)

Options:
  --all   Dump all readable attributes for detected BAT*/AC*/ADP* devices
  --help  Show this help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --all)
      SHOW_ALL=1; shift 1 ;;
    --help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

read_file_trim() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  tr -d '\n' <"$path" 2>/dev/null
}

read_int() {
  local path="$1"
  local v
  v="$(read_file_trim "$path" 2>/dev/null || true)"
  [[ "$v" =~ ^-?[0-9]+$ ]] || return 1
  echo "$v"
}

fmt_ratio_pct() {
  local num="$1"
  local den="$2"
  awk -v n="$num" -v d="$den" 'BEGIN { if (d==0) { print "n/a" } else { printf "%.1f%%", (n/d)*100 } }'
}

fmt_uunit() {
  local v="$1"
  local scale="$2"
  awk -v x="$v" -v s="$scale" 'BEGIN { printf "%.3f", x/s }'
}

fmt_uewh() {
  local v="$1"
  awk -v x="$v" 'BEGIN { printf "%.3f Wh", x/1000000 }'
}

fmt_uah() {
  local v="$1"
  awk -v x="$v" 'BEGIN { printf "%.3f Ah", x/1000000 }'
}

fmt_uv() {
  local v="$1"
  awk -v x="$v" 'BEGIN { printf "%.3f V", x/1000000 }'
}

fmt_ua() {
  local v="$1"
  awk -v x="$v" 'BEGIN { printf "%.3f A", x/1000000 }'
}

fmt_uw() {
  local v="$1"
  awk -v x="$v" 'BEGIN { printf "%.3f W", x/1000000 }'
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

fmt_temp_mdegc() {
  local v="$1"
  awk -v x="$v" 'BEGIN { printf "%.1f°C", x/1000 }'
}

find_node_from_helper() {
  local helper="$1"
  if [[ -f "$helper" ]]; then
    bash "$helper" 2>/dev/null || true
  fi
}

print_header() {
  echo "Battery full status"
  echo
}

print_acer_wmi_battery_section() {
  echo "[acer-wmi-battery]"

  local health_mode_path="/sys/bus/wmi/drivers/acer-wmi-battery/health_mode"
  local calibration_mode_path="/sys/bus/wmi/drivers/acer-wmi-battery/calibration_mode"
  local temp_path
  temp_path="$(find_node_from_helper "${script_dir}/find_temperature_node.sh")"

  if [[ -f "$health_mode_path" ]]; then
    echo "health_mode: $(read_file_trim "$health_mode_path" || echo 'n/a')"
  else
    echo "health_mode: n/a"
  fi

  if [[ -f "$calibration_mode_path" ]]; then
    echo "calibration_mode: $(read_file_trim "$calibration_mode_path" || echo 'n/a')"
  else
    echo "calibration_mode: n/a"
  fi

  if [[ -n "${temp_path:-}" && -f "$temp_path" ]]; then
    local t
    t="$(read_int "$temp_path" 2>/dev/null || true)"
    if [[ -n "${t:-}" ]]; then
      echo "temperature: $(fmt_temp_mdegc "$t") (${t} m°C)"
      echo "temperature_node: $temp_path"
    else
      echo "temperature: n/a"
    fi
  else
    echo "temperature: n/a"
  fi

  echo
}

print_power_supply_device() {
  local dev_path="$1"
  local dev
  dev="$(basename "$dev_path")"

  echo "[$dev]"

  local type
  type="$(read_file_trim "$dev_path/type" 2>/dev/null || true)"
  [[ -n "${type:-}" ]] && echo "type: $type"

  local manufacturer model_name serial_number technology
  manufacturer="$(read_file_trim "$dev_path/manufacturer" 2>/dev/null || true)"
  model_name="$(read_file_trim "$dev_path/model_name" 2>/dev/null || true)"
  serial_number="$(read_file_trim "$dev_path/serial_number" 2>/dev/null || true)"
  technology="$(read_file_trim "$dev_path/technology" 2>/dev/null || true)"

  [[ -n "${manufacturer:-}" ]] && echo "manufacturer: $manufacturer"
  [[ -n "${model_name:-}" ]] && echo "model_name: $model_name"
  [[ -n "${serial_number:-}" ]] && echo "serial_number: $serial_number"
  [[ -n "${technology:-}" ]] && echo "technology: $technology"

  local status capacity capacity_level present online
  status="$(read_file_trim "$dev_path/status" 2>/dev/null || true)"
  capacity="$(read_file_trim "$dev_path/capacity" 2>/dev/null || true)"
  capacity_level="$(read_file_trim "$dev_path/capacity_level" 2>/dev/null || true)"
  present="$(read_file_trim "$dev_path/present" 2>/dev/null || true)"
  online="$(read_file_trim "$dev_path/online" 2>/dev/null || true)"

  [[ -n "${status:-}" ]] && echo "status: $status"
  [[ -n "${capacity:-}" ]] && echo "capacity: ${capacity}%"
  [[ -n "${capacity_level:-}" ]] && echo "capacity_level: $capacity_level"
  [[ -n "${present:-}" ]] && echo "present: $present"
  [[ -n "${online:-}" ]] && echo "online: $online"

  local voltage_now current_now power_now
  voltage_now="$(read_int "$dev_path/voltage_now" 2>/dev/null || true)"
  current_now="$(read_int "$dev_path/current_now" 2>/dev/null || true)"
  power_now="$(read_int "$dev_path/power_now" 2>/dev/null || true)"

  [[ -n "${voltage_now:-}" ]] && echo "voltage_now: $(fmt_uv "$voltage_now")"
  [[ -n "${current_now:-}" ]] && echo "current_now: $(fmt_ua "$current_now")"
  [[ -n "${power_now:-}" ]] && echo "power_now: $(fmt_uw "$power_now")"

  local time_to_full_now time_to_empty_now eta_seconds
  time_to_full_now="$(read_int "$dev_path/time_to_full_now" 2>/dev/null || true)"
  time_to_empty_now="$(read_int "$dev_path/time_to_empty_now" 2>/dev/null || true)"

  if [[ -n "${time_to_full_now:-}" ]]; then
    echo "time_to_full_now: $(fmt_seconds_hhmm "$time_to_full_now") (${time_to_full_now}s)"
  fi

  if [[ -n "${time_to_empty_now:-}" ]]; then
    echo "time_to_empty_now: $(fmt_seconds_hhmm "$time_to_empty_now") (${time_to_empty_now}s)"
  fi

  local energy_now energy_full energy_full_design
  energy_now="$(read_int "$dev_path/energy_now" 2>/dev/null || true)"
  energy_full="$(read_int "$dev_path/energy_full" 2>/dev/null || true)"
  energy_full_design="$(read_int "$dev_path/energy_full_design" 2>/dev/null || true)"

  local charge_now charge_full charge_full_design
  charge_now="$(read_int "$dev_path/charge_now" 2>/dev/null || true)"
  charge_full="$(read_int "$dev_path/charge_full" 2>/dev/null || true)"
  charge_full_design="$(read_int "$dev_path/charge_full_design" 2>/dev/null || true)"

  if [[ -n "${energy_full:-}" || -n "${energy_full_design:-}" || -n "${energy_now:-}" ]]; then
    [[ -n "${energy_now:-}" ]] && echo "energy_now: $(fmt_uewh "$energy_now")"
    [[ -n "${energy_full:-}" ]] && echo "energy_full: $(fmt_uewh "$energy_full")"
    [[ -n "${energy_full_design:-}" ]] && echo "energy_full_design: $(fmt_uewh "$energy_full_design")"
    if [[ -n "${energy_full:-}" && -n "${energy_full_design:-}" ]]; then
      echo "full_vs_design: $(fmt_ratio_pct "$energy_full" "$energy_full_design")"
    fi
  fi

  if [[ -n "${charge_full:-}" || -n "${charge_full_design:-}" || -n "${charge_now:-}" ]]; then
    [[ -n "${charge_now:-}" ]] && echo "charge_now: $(fmt_uah "$charge_now")"
    [[ -n "${charge_full:-}" ]] && echo "charge_full: $(fmt_uah "$charge_full")"
    [[ -n "${charge_full_design:-}" ]] && echo "charge_full_design: $(fmt_uah "$charge_full_design")"
    if [[ -n "${charge_full:-}" && -n "${charge_full_design:-}" ]]; then
      echo "full_vs_design: $(fmt_ratio_pct "$charge_full" "$charge_full_design")"
    fi
  fi

  if [[ -z "${time_to_full_now:-}" && -z "${time_to_empty_now:-}" && -n "${status:-}" ]]; then
    eta_seconds="$(estimate_eta_seconds "$status" "$energy_now" "$energy_full" "$power_now" "$charge_now" "$charge_full" "$current_now" 2>/dev/null || true)"
    if [[ -n "${eta_seconds:-}" ]]; then
      if [[ "$status" == "Charging" ]]; then
        echo "eta_to_full_estimate: $(fmt_seconds_hhmm "$eta_seconds") (${eta_seconds}s)"
      elif [[ "$status" == "Discharging" ]]; then
        echo "eta_to_empty_estimate: $(fmt_seconds_hhmm "$eta_seconds") (${eta_seconds}s)"
      fi
    fi
  fi

  local temp
  temp="$(read_int "$dev_path/temp" 2>/dev/null || true)"
  if [[ -n "${temp:-}" ]]; then
    echo "temp: $temp"
  fi

  if [[ "$SHOW_ALL" -eq 1 ]]; then
    echo
    echo "attributes:"
    local f base
    while IFS= read -r -d '' f; do
      base="$(basename "$f")"
      [[ "$base" == "uevent" ]] && continue
      [[ "$base" == "subsystem" ]] && continue
      [[ "$base" == "device" ]] && continue
      if [[ -f "$f" && -r "$f" ]]; then
        printf "- %s=%s\n" "$base" "$(read_file_trim "$f" 2>/dev/null || true)"
      fi
    done < <(find "$dev_path" -maxdepth 1 -type f -print0 2>/dev/null | sort -z)
  fi

  echo
}

main() {
  print_header
  print_acer_wmi_battery_section

  local dev
  local any=0
  shopt -s nullglob
  for dev in /sys/class/power_supply/*; do
    [[ -d "$dev" ]] || continue
    any=1
    print_power_supply_device "$dev"
  done
  shopt -u nullglob

  if [[ "$any" -eq 0 ]]; then
    echo "No power_supply devices found under /sys/class/power_supply" >&2
    exit 1
  fi
}

main
