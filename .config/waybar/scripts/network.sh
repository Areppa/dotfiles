#!/usr/bin/env bash

# Settings
PING_TARGET="1.1.1.1"
PING_TIMEOUT=2                    # seconds
PING_WARN_MS=25                  # high-ping threshold in milliseconds

TAILSCALE_TARGET="homeassistant"  # replace with a reachable Tailnet device
TAILSCALE_TIMEOUT=2               # seconds

HIGH_UPLOAD_LIMIT_MBPS=5          # alert when upload is over this; 0 disables it
HIGH_DOWNLOAD_LIMIT_MBPS=20       # alert when download is over this; 0 disables it
HISTORY_COUNT=3                   # average this many samples

# Icons
ICON_WIFI=" "
ICON_ETHERNET="󰈀"
ICON_DISCONNECTED="⚠"
ICON_VPN="VPN"
ICON_HIGH_PING="!"
DOWNLOAD_ICON="↓"
UPLOAD_ICON="↑"

# Keep rate history and counters between Waybar executions.
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/waybar-network-${UID}"
STATE_FILE="$STATE_DIR/state"
HISTORY_FILE="$STATE_DIR/history"
LOCK_FILE="$STATE_DIR/lock"

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR" 2>/dev/null || true
exec 9>"$LOCK_FILE"
flock 9

# Keep the history count valid.
if ! [[ "$HISTORY_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    HISTORY_COUNT=1
fi

# Find the interface used to reach the ping target.
IFACE=$(
    ip -o route get "$PING_TARGET" 2>/dev/null |
        awk '{for (i = 1; i <= NF; i++) if ($i == "dev") {print $(i + 1); exit}}'
)

CLASS="connected"
PING_DETAIL="Unreachable"
DEVICE_TYPE=""
DOWNLOAD_RATE="0.00"
UPLOAD_RATE="0.00"

if [[ -z "$IFACE" ]]; then
    CLASS="no-internet"
else
    # Ask NetworkManager for the connection type when available.
    if command -v nmcli >/dev/null 2>&1; then
        DEVICE_TYPE=$(nmcli -g GENERAL.TYPE device show "$IFACE" 2>/dev/null || true)
    fi

    # Ping once to check internet reachability and measure latency.
    if PING_OUTPUT=$(ping -n -c 1 -W "$PING_TIMEOUT" "$PING_TARGET" 2>&1); then
        LATENCY=$(sed -nE 's/.*time=([0-9.]+).*/\1/p' <<<"$PING_OUTPUT" | head -n 1)

        # Handle iputils output such as "time<1".
        [[ -n "$LATENCY" ]] || LATENCY="0.5"
        PING_DETAIL="Reachable (${LATENCY} ms)"

        if awk -v ms="$LATENCY" -v limit="$PING_WARN_MS" \
            'BEGIN { exit !(ms >= limit) }'; then
            CLASS="high-ping"
            PING_DETAIL+=" — HIGH"
        fi
    else
        CLASS="no-internet"
        PING_DETAIL="Unreachable"
    fi
fi

# Read the interface's received and transmitted byte counters.
read_counters() {
    awk -v interface="$1" '
        $1 == interface ":" {
            print $2, $10
            found = 1
        }
        END {
            if (!found) print "0 0"
        }
    ' /proc/net/dev
}

read -r OLD_IFACE OLD_RX OLD_TX OLD_TIME < "$STATE_FILE" 2>/dev/null || true
read -r NEW_RX NEW_TX <<< "$(read_counters "$IFACE")"
NOW_NS=$(date +%s%N)

# Reset the rate history if the active interface changed.
if [[ -z "$IFACE" || "$OLD_IFACE" != "$IFACE" ]]; then
    : > "$HISTORY_FILE"
fi

# Calculate Mbps since the previous script run.
if [[ -n "$IFACE" &&
      "$OLD_IFACE" == "$IFACE" &&
      "$OLD_RX" =~ ^[0-9]+$ &&
      "$OLD_TX" =~ ^[0-9]+$ &&
      "$OLD_TIME" =~ ^[0-9]+$ &&
      "$NEW_RX" =~ ^[0-9]+$ &&
      "$NEW_TX" =~ ^[0-9]+$ &&
      "$NOW_NS" =~ ^[0-9]+$ ]] &&
   (( NEW_RX >= OLD_RX && NEW_TX >= OLD_TX && NOW_NS > OLD_TIME )); then

    ELAPSED_NS=$((NOW_NS - OLD_TIME))
    RX_BYTES=$((NEW_RX - OLD_RX))
    TX_BYTES=$((NEW_TX - OLD_TX))

    DOWNLOAD_RATE=$(awk -v bytes="$RX_BYTES" -v ns="$ELAPSED_NS" \
        'BEGIN { printf "%.2f", bytes * 8000 / ns }')
    UPLOAD_RATE=$(awk -v bytes="$TX_BYTES" -v ns="$ELAPSED_NS" \
        'BEGIN { printf "%.2f", bytes * 8000 / ns }')
fi

# Save counters and timestamp for the next run.
printf '%s %s %s %s\n' "$IFACE" "$NEW_RX" "$NEW_TX" "$NOW_NS" > "$STATE_FILE"

# Keep and average the most recent download/upload samples.
if [[ -n "$IFACE" ]]; then
    HISTORY_TMP="${HISTORY_FILE}.tmp"
    {
        tail -n "$((HISTORY_COUNT - 1))" "$HISTORY_FILE" 2>/dev/null || true
        printf '%s %s\n' "$DOWNLOAD_RATE" "$UPLOAD_RATE"
    } > "$HISTORY_TMP"
    mv "$HISTORY_TMP" "$HISTORY_FILE"

    read -r DOWNLOAD_RATE UPLOAD_RATE < <(
        awk '
            { download += $1; upload += $2; count++ }
            END {
                if (count > 0)
                    printf "%.2f %.2f\n", download / count, upload / count
                else
                    print "0.00 0.00"
            }
        ' "$HISTORY_FILE"
    )
else
    DOWNLOAD_RATE="0.00"
    UPLOAD_RATE="0.00"
fi

# Select the connection-type icon.
case "$DEVICE_TYPE" in
    *wifi*|*wireless*)
        NET_ICON="$ICON_WIFI"
        ;;
    *ethernet*)
        NET_ICON="$ICON_ETHERNET"
        ;;
    *)
        if [[ -n "$IFACE" && -d "/sys/class/net/$IFACE/wireless" ]]; then
            NET_ICON="$ICON_WIFI"
        elif [[ -n "$IFACE" ]]; then
            NET_ICON="$ICON_ETHERNET"
        else
            NET_ICON=""
        fi
        ;;
esac

# Check Tailscale using the configured Tailnet host, then fall back
# to Tailscale's local daemon status.
VPN_CONNECTED=0
VPN_DETAIL="Tailscale disconnected"

if command -v tailscale >/dev/null 2>&1; then
    if [[ -n "$TAILSCALE_TARGET" ]] &&
        tailscale ping -c 1 -t "$TAILSCALE_TIMEOUT" "$TAILSCALE_TARGET" \
            >/dev/null 2>&1; then
        VPN_CONNECTED=1
        VPN_DETAIL="Tailscale connected"
    else
        TS_STATUS=$(tailscale status --json 2>/dev/null || true)
        if jq -e '.Self.Online == true' >/dev/null 2>&1 <<<"$TS_STATUS"; then
            VPN_CONNECTED=1
            VPN_DETAIL="Tailscale online; Tailnet host did not respond"
        fi
    fi
fi

# Build the visible text. When internet is down, show only the disconnected icon.
if [[ "$CLASS" == "no-internet" ]]; then
    TEXT="$ICON_DISCONNECTED"
    CLASS="disconnected"
else
    TEXT="$NET_ICON"

    if (( VPN_CONNECTED )); then
        TEXT+=" ${ICON_VPN} VPN"
    fi

    if [[ "$CLASS" == "high-ping" ]]; then
        TEXT="${ICON_HIGH_PING} ${TEXT}"
    fi

    # Add a speed alert only when the measured average is over its limit.
    if awk -v rate="$UPLOAD_RATE" -v limit="$HIGH_UPLOAD_LIMIT_MBPS" \
        'BEGIN { exit !(limit > 0 && rate > limit) }'; then
        TEXT+=" ${UPLOAD_ICON} ${UPLOAD_RATE} Mbps"
    fi

    if awk -v rate="$DOWNLOAD_RATE" -v limit="$HIGH_DOWNLOAD_LIMIT_MBPS" \
        'BEGIN { exit !(limit > 0 && rate > limit) }'; then
        TEXT+=" ${DOWNLOAD_ICON} ${DOWNLOAD_RATE} Mbps"
    fi

fi

TOOLTIP=$(printf \
    'Interface: %s\nInternet ping: %s\nDownload: %s %s Mbps\nUpload: %s %s Mbps\nVPN: %s' \
    "${IFACE:-none}" \
    "$PING_DETAIL" \
    "$DOWNLOAD_ICON" "$DOWNLOAD_RATE" \
    "$UPLOAD_ICON" "$UPLOAD_RATE" \
    "$VPN_DETAIL")

# Waybar custom module JSON output.
jq -cn \
    --arg text "$TEXT" \
    --arg tooltip "$TOOLTIP" \
    --arg class "$CLASS" \
    '{text: $text, tooltip: $tooltip, class: $class}'
