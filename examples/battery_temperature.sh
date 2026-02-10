#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
node="$(bash "${script_dir}/find_temperature_node.sh")"

val="$(cat "$node" 2>/dev/null || true)"
if ! [[ "$val" =~ ^-?[0-9]+$ ]]; then
  echo "Unexpected contents in temperature node: $node" >&2
  echo "Value was: '$val'" >&2
  exit 1
fi

# Upstream reports millidegree Celsius
awk -v v="$val" 'BEGIN { printf "%.1f°C\n", v/1000 }'
