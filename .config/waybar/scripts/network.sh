#!/usr/bin/env bash

# Settings
PING_TARGET="1.1.1.1"
PING_TIMEOUT=2          # seconds
PING_WARN_MS=25        # show alert at or above this latency, in milliseconds

TAILSCALE_TARGET="homeassistant"  # replace with a reachable Tailnet device
TAILSCALE_TIMEOUT=2     # seconds

# Icons
ICON_WIFI=" "
ICON_ETHERNET="󰈀"
ICON_DISCONNECTED="⚠"
ICON_VPN="VPN"
ICON_HIGH_PING="!"

# Find the interface used to reach the ping target.
IFACE=$(
    ip -o route get "$PING_TARGET" 2>/dev/null |
        awk '{for (i = 1; i <= NF; i++) if ($i == "dev") {print $(i + 1); exit}}'
)

CLASS="connected"
PING_DETAIL="Unreachable"
DEVICE_TYPE=""

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

# Build the visible text. If internet is down, show only the disconnected icon.
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
fi

TOOLTIP=$(printf 'Interface: %s\nInternet ping: %s\nVPN: %s' \
    "${IFACE:-none}" "$PING_DETAIL" "$VPN_DETAIL")

# Waybar custom module JSON output.
jq -cn \
    --arg text "$TEXT" \
    --arg tooltip "$TOOLTIP" \
    --arg class "$CLASS" \
    '{text: $text, tooltip: $tooltip, class: $class}'
