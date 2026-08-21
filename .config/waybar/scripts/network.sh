#!/usr/bin/env bash

# Configuration
DOWNLOAD_ICON="↓ "
UPLOAD_ICON="↑ "
SHOW_MBPS=true
HISTORY_COUNT=3        # Number of samples to average

mode="download"
limit="0"

while getopts ":DUL:mn" opt; do
    case "$opt" in
        D) mode="download" ;;
        U) mode="upload" ;;
        L) limit="$OPTARG" ;;
        m) SHOW_MBPS=true ;;
        n) SHOW_MBPS=false ;;
        *) exit 1 ;;
    esac
done

base="${XDG_RUNTIME_DIR:-/tmp}/waybar-network-${UID}"
history="${base}-${mode}"
lock="${history}.lock"

exec 9>"$lock"
flock 9

interface=$(ip route show default 2>/dev/null | awk 'NR == 1 { print $5; exit }')

read_counters() {
    awk -v interface="$interface" '
        $1 == interface ":" {
            rx = $2
            tx = $10
        }
        END {
            print rx + 0, tx + 0
        }
    ' /proc/net/dev
}

read -r old_rx old_tx <<< "$(read_counters)"
sleep 1
read -r new_rx new_tx <<< "$(read_counters)"

if [[ "$mode" == "download" ]]; then
    bytes=$((new_rx - old_rx))
    icon="$DOWNLOAD_ICON"
else
    bytes=$((new_tx - old_tx))
    icon="$UPLOAD_ICON"
fi

rate=$(awk -v bytes="$bytes" \
    'BEGIN { printf "%.2f", bytes * 8 / 1000000 }')

tmp="${history}.tmp"

{
    tail -n "$((HISTORY_COUNT - 1))" "$history" 2>/dev/null
    printf '%s\n' "$rate"
} > "$tmp"

mv "$tmp" "$history"

average=$(awk '{ sum += $1 } END { printf "%.2f", sum / NR }' "$history")

if awk -v average="$average" -v limit="$limit" \
    'BEGIN { exit !(average >= limit) }'; then

    awk -v average="$average" \
        -v icon="$icon" \
        -v show_mbps="$SHOW_MBPS" '
        BEGIN {
            if (average < 1) {
                format = "%.2f"
            } else if (average < 10) {
                format = "%.1f"
            } else {
                format = "%.0f"
            }

            suffix = (show_mbps == "true") ? " Mbps" : ""

            printf "%s" format "%s\n", icon, average, suffix
        }
    '
fi
