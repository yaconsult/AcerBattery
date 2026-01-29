#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
node="$("${script_dir}"/find_health_mode_node.sh writable)"

echo 0 | sudo tee "$node" >/dev/null
echo "Disabled charge limit (health_mode=0) via: $node"
