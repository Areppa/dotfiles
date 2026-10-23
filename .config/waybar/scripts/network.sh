#!/usr/bin/env bash

# Settings
PING_TARGET="1.1.1.1"
PING_TIMEOUT=2
PING_WARN_MS=50
VPN_PING_WARN_MS=100
TAILSCALE_TIMEOUT=2
HIGH_UPLOAD_LIMIT_MBPS=5
HIGH_DOWNLOAD_LIMIT_MBPS=20
HISTORY_COUNT=3
PING_HISTORY_COUNT=10

# Icons
ICON_WIFI=" "
ICON_ETHERNET="󰈀"
ICON_DISCONNECTED="⚠"
ICON_VPN="VPN"
ICON_HIGH_PING="!"
DOWNLOAD_ICON="↓"
UPLOAD_ICON="↑"

export LC_ALL=C

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/waybar-network-${UID}"
STATE_FILE="$STATE_DIR/state"
HISTORY_FILE="$STATE_DIR/history"
PING_HISTORY_FILE="$STATE_DIR/ping-history"
LOCK_FILE="$STATE_DIR/lock"

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR" 2>/dev/null || :
exec 9>"$LOCK_FILE"
flock 9

[[ "$HISTORY_COUNT" =~ ^[1-9][0-9]*$ ]] || HISTORY_COUNT=1
[[ "$PING_HISTORY_COUNT" =~ ^[1-9][0-9]*$ ]] || PING_HISTORY_COUNT=1

HISTORY_COUNT=$((10#$HISTORY_COUNT))
PING_HISTORY_COUNT=$((10#$PING_HISTORY_COUNT))

# Format ping and speed values.
format_value() {
    awk -v value="$1" 'BEGIN {
        if (value < 1) printf "%.2f", value
        else if (value < 10) printf "%.1f", value
        else printf "%.0f", value
    }'
}

# Find the interface used to reach the ping target. This may be a VPN tunnel.
ROUTE_IFACE=$(
    ip -o route get "$PING_TARGET" 2>/dev/null |
        awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
)

# Find the physical interface, preferring connected Wi-Fi or Ethernet.
IFACE=""
if command -v nmcli >/dev/null 2>&1; then
    IFACE=$(
        nmcli -t --escape no -f DEVICE,TYPE,STATE device status 2>/dev/null |
            awk -F: '$3 == "connected" && ($2 == "wifi" || $2 == "ethernet") { print $1; exit }'
    )
fi

# Without NetworkManager, prefer a hardware-backed route interface.
if [[ -z "$IFACE" && -n "$ROUTE_IFACE" ]]; then
    if [[ -d "/sys/class/net/$ROUTE_IFACE/device" ||
          -d "/sys/class/net/$ROUTE_IFACE/wireless" ]]; then
        IFACE="$ROUTE_IFACE"
    fi
fi

# If the route uses a tunnel, look for a hardware-backed default-route interface.
if [[ -z "$IFACE" ]]; then
    while IFS= read -r candidate; do
        if [[ -d "/sys/class/net/$candidate/device" ||
              -d "/sys/class/net/$candidate/wireless" ]]; then
            IFACE="$candidate"
            break
        fi
    done < <(
        ip -o route show table main default 2>/dev/null |
            awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); break } }'
    )
fi

CLASS="connected"
PING_DETAIL="Unreachable"
PING_MS=""
PING_SAMPLE=""
PING_REACHABLE=0
DEVICE_TYPE=""
DOWNLOAD_RATE="0.00"
UPLOAD_RATE="0.00"

if [[ -z "$ROUTE_IFACE" ]]; then
    CLASS="no-internet"
else
    if [[ -n "$IFACE" ]] && command -v nmcli >/dev/null 2>&1; then
        DEVICE_TYPE=$(nmcli -g GENERAL.TYPE device show "$IFACE" 2>/dev/null || :)
    fi

    if PING_OUTPUT=$(ping -n -c 1 -W "$PING_TIMEOUT" "$PING_TARGET" 2>&1); then
        PING_MS=$(sed -nE 's/.*time=([0-9.]+).*/\1/p' <<<"$PING_OUTPUT" | head -n 1)
        [[ -n "$PING_MS" ]] || PING_MS="0.5"
        PING_DETAIL="$(format_value "$PING_MS") ms"
        PING_SAMPLE="$PING_MS"
        PING_REACHABLE=1
    fi
fi

# Read received/transmitted byte counters for an interface.
read_counters() {
    awk -v iface="$1" '
        $1 == iface ":" { print $2, $10; found = 1 }
        END { if (!found) print "0 0" }
    ' /proc/net/dev
}

STATE_IFACE="${IFACE:--}"
read -r OLD_IFACE OLD_RX OLD_TX OLD_TIME < "$STATE_FILE" 2>/dev/null || :
read -r NEW_RX NEW_TX <<<"$(read_counters "$IFACE")"
NOW_NS=$(date +%s%N)

# Reset rate and ping history when the physical interface changes or is unavailable.
if [[ -z "$IFACE" || "$OLD_IFACE" != "$STATE_IFACE" ]]; then
    : > "$HISTORY_FILE"
    : > "$PING_HISTORY_FILE"
fi

# Calculate Mbps since the previous run.
if [[ -n "$IFACE" &&
      "$OLD_IFACE" == "$STATE_IFACE" &&
      "$OLD_RX" =~ ^[0-9]+$ &&
      "$OLD_TX" =~ ^[0-9]+$ &&
      "$OLD_TIME" =~ ^[0-9]+$ &&
      "$NEW_RX" =~ ^[0-9]+$ &&
      "$NEW_TX" =~ ^[0-9]+$ &&
      "$NOW_NS" =~ ^[0-9]+$ ]] &&
   (( NEW_RX >= OLD_RX && NEW_TX >= OLD_TX && NOW_NS > OLD_TIME )); then

    ELAPSED_NS=$((NOW_NS - OLD_TIME))
    DOWNLOAD_RATE=$(awk -v bytes="$((NEW_RX - OLD_RX))" -v ns="$ELAPSED_NS" \
        'BEGIN { printf "%.2f", bytes * 8000 / ns }')
    UPLOAD_RATE=$(awk -v bytes="$((NEW_TX - OLD_TX))" -v ns="$ELAPSED_NS" \
        'BEGIN { printf "%.2f", bytes * 8000 / ns }')
fi

# Save counters and timestamp for the next run.
STATE_TMP="${STATE_FILE}.tmp"
printf '%s %s %s %s\n' "$STATE_IFACE" "$NEW_RX" "$NEW_TX" "$NOW_NS" > "$STATE_TMP"
mv "$STATE_TMP" "$STATE_FILE"

PING_AVERAGE="Unavailable"

if [[ -n "$IFACE" ]]; then
    # Keep speed samples in their own history file.
    HISTORY_TMP="${HISTORY_FILE}.tmp"
    {
        tail -n "$((HISTORY_COUNT - 1))" "$HISTORY_FILE" 2>/dev/null || :
        printf '%s %s\n' "$DOWNLOAD_RATE" "$UPLOAD_RATE"
    } > "$HISTORY_TMP"
    mv "$HISTORY_TMP" "$HISTORY_FILE"

    read -r DOWNLOAD_RATE UPLOAD_RATE < <(
        awk -v limit="$HISTORY_COUNT" '
            $1 ~ /^[0-9]+([.][0-9]+)?$/ && $2 ~ /^[0-9]+([.][0-9]+)?$/ {
                download[++n] = $1
                upload[n] = $2
            }
            END {
                start = n - limit + 1
                if (start < 1) start = 1
                for (i = start; i <= n; i++) {
                    d += download[i]
                    u += upload[i]
                    count++
                }
                if (count) printf "%.2f %.2f\n", d / count, u / count
                else print "0.00 0.00"
            }
        ' "$HISTORY_FILE"
    )

    # Keep successful ping samples in their own history file.
    PING_HISTORY_TMP="${PING_HISTORY_FILE}.tmp"
    {
        tail -n "$((PING_HISTORY_COUNT - 1))" "$PING_HISTORY_FILE" 2>/dev/null || :
        if [[ -n "$PING_SAMPLE" ]]; then
            printf '%s\n' "$PING_SAMPLE"
        fi
    } > "$PING_HISTORY_TMP"
    mv "$PING_HISTORY_TMP" "$PING_HISTORY_FILE"

    PING_AVERAGE_VALUE=$(
        awk -v limit="$PING_HISTORY_COUNT" '
            $1 ~ /^[0-9]+([.][0-9]+)?$/ { ping[++n] = $1 }
            END {
                start = n - limit + 1
                if (start < 1) start = 1
                for (i = start; i <= n; i++) {
                    total += ping[i]
                    count++
                }
                if (count) printf "%.17g\n", total / count
            }
        ' "$PING_HISTORY_FILE"
    )

    if [[ -n "$PING_AVERAGE_VALUE" ]]; then
        PING_AVERAGE="$(format_value "$PING_AVERAGE_VALUE") ms"
    else
        PING_AVERAGE="Unavailable"
    fi
else
    DOWNLOAD_RATE="0.00"
    UPLOAD_RATE="0.00"
fi

DOWNLOAD_RATE_DISPLAY=$(format_value "$DOWNLOAD_RATE")
UPLOAD_RATE_DISPLAY=$(format_value "$UPLOAD_RATE")

# Check Tailscale and ping the selected exit node.
VPN_CONNECTED=0
VPN_DETAIL="Disconnected"
TS_STATUS=""
EXIT_NODE_ID=""
TAILSCALE_TARGET=""

if command -v tailscale >/dev/null 2>&1; then
    TS_STATUS=$(tailscale status --json 2>/dev/null || :)
    EXIT_NODE_ID=$(jq -r '.ExitNodeStatus.ID // empty' <<<"$TS_STATUS")

    if [[ -n "$EXIT_NODE_ID" ]]; then
        TAILSCALE_TARGET=$(
            jq -r --arg exit_id "$EXIT_NODE_ID" '
                (
                    [.Peer[]?
                     | select(.ID == $exit_id)
                     | .TailscaleIPs[0] // empty][0]
                )
                // .ExitNodeStatus.TailscaleIPs[0]
                // empty
            ' <<<"$TS_STATUS"
        )

        if [[ -n "$TAILSCALE_TARGET" ]] &&
           tailscale ping --c=1 --timeout="${TAILSCALE_TIMEOUT}s" "$TAILSCALE_TARGET" \
               >/dev/null 2>&1; then
            VPN_CONNECTED=1
        fi
    fi

    if (( ! VPN_CONNECTED )) &&
       jq -e '.Self.Online == true' >/dev/null 2>&1 <<<"$TS_STATUS"; then
        VPN_CONNECTED=1
    fi

    if (( VPN_CONNECTED )); then
        if [[ -n "$EXIT_NODE_ID" ]]; then
            EXIT_NODE_NAME=$(
                jq -r --arg exit_id "$EXIT_NODE_ID" '
                    [
                        .Peer[]?
                        | select(.ID == $exit_id)
                        | (.HostName // .DNSName // empty)
                    ][0] // empty
                ' <<<"$TS_STATUS"
            )

            [[ -n "$EXIT_NODE_NAME" ]] || EXIT_NODE_NAME="$TAILSCALE_TARGET"
            EXIT_NODE_ONLINE=$(jq -r '.ExitNodeStatus.Online // false' <<<"$TS_STATUS")

            if [[ "$EXIT_NODE_ONLINE" == "true" ]]; then
                VPN_DETAIL="Connected (${EXIT_NODE_NAME})"
            else
                VPN_DETAIL="Exit node: ${EXIT_NODE_NAME} (offline)"
            fi
        else
            VPN_DETAIL="Connected (no exit node)"
        fi
    fi
fi

# Apply the appropriate high-ping threshold to the average ping.
if [[ "$CLASS" != "no-internet" && -n "$PING_AVERAGE_VALUE" ]]; then
    PING_LIMIT="$PING_WARN_MS"
    if (( VPN_CONNECTED )); then
        PING_LIMIT="$VPN_PING_WARN_MS"
    fi

    if awk -v ms="$PING_AVERAGE_VALUE" -v limit="$PING_LIMIT" \
        'BEGIN { exit !(ms >= limit) }'; then
        CLASS="high-ping"
    fi
fi

# Select the physical connection-type icon.
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

# Get the local IPv4 address for the selected interface.
LOCAL_IP=""
if [[ -n "$IFACE" ]]; then
    LOCAL_IP=$(
        ip -o -4 addr show dev "$IFACE" scope global 2>/dev/null |
            awk 'NR == 1 { split($4, address, "/"); print address[1]; exit }'
    )
fi
[[ -n "$LOCAL_IP" ]] || LOCAL_IP="—"

# Get the Wi-Fi name and signal rating.
WIFI_TOOLTIP=""
if [[ -n "$IFACE" && "$NET_ICON" == "$ICON_WIFI" ]]; then
    WIFI_SSID="—"
    WIFI_SIGNAL="Unavailable"
    WIFI_SIGNAL_DBM=""

    if command -v iw >/dev/null 2>&1; then
        LINK_INFO=$(iw dev "$IFACE" link 2>/dev/null || :)

        WIFI_SSID=$(awk '
            /^[[:space:]]*SSID: / {
                sub(/^[[:space:]]*SSID: /, "")
                print
                exit
            }
        ' <<<"$LINK_INFO")
        [[ -n "$WIFI_SSID" ]] || WIFI_SSID="—"

        SIGNAL_DBM=$(awk '/^[[:space:]]*signal:/ { print $2; exit }' <<<"$LINK_INFO")
        if [[ "$SIGNAL_DBM" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
            WIFI_SIGNAL=$(awk -v signal="$SIGNAL_DBM" 'BEGIN {
                if (signal >= -50) quality = "Excellent"
                else if (signal >= -60) quality = "Good"
                else if (signal >= -70) quality = "Fair"
                else quality = "Weak"
                print quality
            }')
            WIFI_SIGNAL_DBM="$SIGNAL_DBM"

            NET_ICON=$(awk -v signal="$SIGNAL_DBM" 'BEGIN {
                if (signal >= -50)      print "󰤨 "
                else if (signal >= -60) print "󰤥 "
                else if (signal >= -70) print "󰤢 "
                else                    print "󰤟 "
            }')
        fi
    fi

    if [[ -n "$WIFI_SIGNAL_DBM" ]]; then
        WIFI_TOOLTIP=$(printf 'WiFi: %s\nSignal: %s %s dBm' \
            "$WIFI_SSID" "$WIFI_SIGNAL" "$WIFI_SIGNAL_DBM")
    else
        WIFI_TOOLTIP=$(printf 'WiFi: %s\nSignal: %s' \
            "$WIFI_SSID" "$WIFI_SIGNAL")
    fi
fi

# Build the visible text.
if [[ "$CLASS" == "no-internet" ]]; then
    TEXT="$ICON_DISCONNECTED"
    CLASS="disconnected"
else
    TEXT="$NET_ICON"

    if (( VPN_CONNECTED )); then
        TEXT+=" ${ICON_VPN}"
    fi

    if [[ "$CLASS" == "high-ping" ]]; then
        TEXT="${ICON_HIGH_PING} ${TEXT}"
    fi

    # Compare unrounded rates to the limits, but display formatted rates.
    if awk -v rate="$UPLOAD_RATE" -v limit="$HIGH_UPLOAD_LIMIT_MBPS" \
        'BEGIN { exit !(limit > 0 && rate > limit) }'; then
        TEXT+=" ${UPLOAD_ICON} ${UPLOAD_RATE_DISPLAY} Mbps"
    fi

    if awk -v rate="$DOWNLOAD_RATE" -v limit="$HIGH_DOWNLOAD_LIMIT_MBPS" \
        'BEGIN { exit !(limit > 0 && rate > limit) }'; then
        TEXT+=" ${DOWNLOAD_ICON} ${DOWNLOAD_RATE_DISPLAY} Mbps"
    fi
fi

TOOLTIP=$(printf \
    'Interface: %s\nLocal IP: %s\n\nPing: %s (avg %s)\n\nDownload: %s %s Mbps\nUpload: %s %s Mbps\n\nTailscale: %s' \
    "${IFACE:-none}" \
    "$LOCAL_IP" \
    "$PING_DETAIL" \
    "$PING_AVERAGE" \
    "$DOWNLOAD_ICON" "$DOWNLOAD_RATE_DISPLAY" \
    "$UPLOAD_ICON" "$UPLOAD_RATE_DISPLAY" \
    "$VPN_DETAIL")

if [[ -n "$WIFI_TOOLTIP" ]]; then
    TOOLTIP=$(printf '%s\n\n%s' "$WIFI_TOOLTIP" "$TOOLTIP")
fi

# Waybar custom module JSON output.
jq -cn \
    --arg text "$TEXT" \
    --arg tooltip "$TOOLTIP" \
    --arg class "$CLASS" \
    '{text: $text, tooltip: $tooltip, class: $class}'
