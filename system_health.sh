#!/usr/bin/env bash
#
# system_health.sh - log CPU, memory and disk usage with a timestamp.
#
# Usage:   ./system_health.sh
# Output:  appends one line to health_log.txt (next to this script) and prints it.
#
# Optional environment overrides:
#   LOG_FILE         where to write the log      (default: <script dir>/health_log.txt)
#   DISK_PATH        filesystem to check         (default: /)
#   DISK_THRESHOLD   warning threshold in %      (default: 80)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${LOG_FILE:-$SCRIPT_DIR/health_log.txt}"
DISK_PATH="${DISK_PATH:-/}"
DISK_THRESHOLD="${DISK_THRESHOLD:-80}"

# CPU usage (%)
get_cpu_usage() {
  local user nice system idle iowait irq softirq steal
  local idle1 total1 idle2 total2

  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  idle1=$((idle + iowait))
  total1=$((user + nice + system + idle + iowait + irq + softirq + steal))

  sleep 1

  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  idle2=$((idle + iowait))
  total2=$((user + nice + system + idle + iowait + irq + softirq + steal))

  awk -v dt=$((total2 - total1)) -v di=$((idle2 - idle1)) \
    'BEGIN { if (dt <= 0) print "0.0"; else printf "%.1f", (dt - di) * 100 / dt }'
}

# Memory usage (%): (total - available) / total.
get_memory_usage() {
  awk '/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 }
       END { printf "%.1f", (t - a) * 100 / t }' /proc/meminfo
}

# Disk usage (%) of DISK_PATH, as an integer.
get_disk_usage() {
  df -P "$DISK_PATH" | awk 'NR == 2 { gsub("%", "", $5); print $5 }'
}

main() {
  local timestamp cpu mem disk
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  cpu="$(get_cpu_usage)"
  mem="$(get_memory_usage)"
  disk="$(get_disk_usage)"

  echo "[$timestamp] CPU: ${cpu}% | Memory: ${mem}% | Disk (${DISK_PATH}): ${disk}%" \
    | tee -a "$LOG_FILE"

  if [ "$disk" -gt "$DISK_THRESHOLD" ]; then
    echo "[$timestamp] [WARNING] Disk space high!" | tee -a "$LOG_FILE"
  fi
}

main "$@"
