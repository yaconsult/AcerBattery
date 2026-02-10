#!/usr/bin/env bash
set -euo pipefail

# Prints a usable sysfs node for reading Acer battery temperature.
# Exit code 0: printed a path
# Exit code 1: nothing found

candidates=()

# Common locations (keep globs, they expand to the actual node name/path)
shopt -s nullglob
candidates+=(/sys/bus/wmi/drivers/*/temperature)
candidates+=(/sys/bus/platform/drivers/*/temperature)
candidates+=(/sys/devices/platform/*/temperature)
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

# Fallback: brute-force scan under /sys for temperature (can be slower)
while IFS= read -r p; do
  [[ -e "$p" ]] || continue
  echo "$p"
  exit 0
done < <(find /sys -maxdepth 6 -type f -name temperature 2>/dev/null)

echo "Could not find a temperature sysfs node. Is the module loaded (sudo modprobe acer_wmi_battery)?" >&2
exit 1
