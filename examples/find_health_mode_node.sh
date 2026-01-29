#!/usr/bin/env bash
set -euo pipefail

# Prints a usable sysfs node for controlling Acer battery health mode.
# Exit code 0: printed a path
# Exit code 1: nothing found

mode="${1:-any}"

if [[ "$mode" != "any" && "$mode" != "writable" ]]; then
  echo "Usage: $0 [any|writable]" >&2
  exit 2
fi

candidates=()

# Common locations (keep globs, they expand to the actual node name/path)
shopt -s nullglob
candidates+=(/sys/bus/wmi/drivers/*/health_mode)
candidates+=(/sys/bus/platform/drivers/*/health_mode)
candidates+=(/sys/devices/platform/*/health_mode)
shopt -u nullglob

# De-duplicate while preserving order
seen=""
uniq_candidates=()
for p in "${candidates[@]}"; do
  [[ -e "$p" ]] || continue
  if [[ "$seen" != *"|$p|"* ]]; then
    seen+="|$p|"
    uniq_candidates+=("$p")
  fi
done

# Prefer paths that look like Acer WMI battery
score_path() {
  local p="$1"
  local s=0
  [[ "$p" == *acer* ]] && s=$((s+10))
  [[ "$p" == *wmi* ]] && s=$((s+5))
  [[ "$p" == *battery* ]] && s=$((s+5))
  echo "$s"
}

best_path=""
best_score=-1

for p in "${uniq_candidates[@]}"; do
  if [[ "$mode" == "writable" ]] && [[ ! -w "$p" ]]; then
    continue
  fi

  s="$(score_path "$p")"
  if (( s > best_score )); then
    best_score="$s"
    best_path="$p"
  fi
done

if [[ -n "$best_path" ]]; then
  echo "$best_path"
  exit 0
fi

# Fallback: brute-force scan under /sys for health_mode (can be slower)
# Still cheap enough on most laptops.
while IFS= read -r p; do
  [[ -e "$p" ]] || continue
  if [[ "$mode" == "writable" ]] && [[ ! -w "$p" ]]; then
    continue
  fi
  echo "$p"
  exit 0
done < <(find /sys -maxdepth 6 -type f -name health_mode 2>/dev/null)

if [[ "$mode" == "writable" ]]; then
  echo "Could not find a writable health_mode sysfs node." >&2
  echo "Hint: try running as root (sudo $0 writable), or use '$0 any' and write with sudo tee." >&2
else
  echo "Could not find a health_mode sysfs node. Is the module loaded (sudo modprobe acer_wmi_battery)?" >&2
fi
exit 1
