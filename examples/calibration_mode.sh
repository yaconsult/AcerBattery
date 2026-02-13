#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage:
  calibration_mode.sh status
  calibration_mode.sh start [--yes]
  calibration_mode.sh stop

This script controls the upstream acer-wmi-battery calibration mode via sysfs.

Notes:
- Calibration can take a long time. Use on AC power and monitor the system.
- This script will prompt for confirmation on 'start' unless --yes is provided.
EOF
}

find_node_from_helper() {
  local helper="$1"
  if [[ -f "$helper" ]]; then
    bash "$helper" 2>/dev/null || true
  fi
}

node_path="$(find_node_from_helper "${script_dir}/find_calibration_mode_node.sh")"

if [[ -z "${node_path:-}" ]]; then
  echo "Could not find a calibration_mode sysfs node. Is the module loaded (sudo modprobe acer_wmi_battery)?" >&2
  exit 1
fi

cmd="${1:-}"

case "$cmd" in
  status)
    if [[ -f "$node_path" ]]; then
      echo "calibration_mode: $(cat "$node_path" 2>/dev/null || echo 'n/a')"
      echo "calibration_mode_node: $node_path"
      exit 0
    fi
    echo "calibration_mode: n/a" >&2
    echo "calibration_mode_node: $node_path" >&2
    exit 1
    ;;

  start)
    yes_flag="${2:-}"

    if [[ "${yes_flag:-}" != "--yes" ]]; then
      echo "Calibration mode can take a long time and is recommended only on AC power." >&2
      echo "It may affect charge/discharge behavior while running." >&2
      read -r -p "Start calibration_mode now? (y/N) " ans
      if [[ "${ans:-}" != "y" && "${ans:-}" != "Y" ]]; then
        echo "Aborted." >&2
        exit 2
      fi
    fi

    echo 1 | sudo tee "$node_path" >/dev/null
    echo "Started calibration_mode (wrote 1)." >&2
    echo "Tip: monitor with 'bash ${script_dir}/battery_full_status.sh'" >&2
    exit 0
    ;;

  stop)
    echo 0 | sudo tee "$node_path" >/dev/null
    echo "Stopped calibration_mode (wrote 0)." >&2
    exit 0
    ;;

  -h|--help|help|"")
    usage
    exit 2
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    usage
    exit 2
    ;;
esac
