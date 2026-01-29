#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
node="$("${script_dir}"/find_health_mode_node.sh any)"

echo 1 | sudo tee "$node" >/dev/null
echo "Enabled charge limit (health_mode=1) via: $node"
