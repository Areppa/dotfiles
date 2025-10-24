#!/usr/bin/env bash
# tailscale-status.sh
# Output only icon based on the connection

ICON_CONNECTED=" VPN"
ICON_DISCONNECTED=""
PING_TARGET="<homeassistant>"   # replace with a reliable Tailnet host
PING_TIMEOUT=2

# Quick ping test
if tailscale ping -c 1 -t $PING_TIMEOUT "$PING_TARGET" >/dev/null 2>&1; then
    echo "$ICON_CONNECTED"
    exit 0
fi

# Fallback: check daemon state
if STATUS=$(tailscale status --json 2>/dev/null); then
    if [[ $(echo "$STATUS" | jq -r '.Self.Online') == "true" ]]; then
        echo "$ICON_CONNECTED"
        exit 0
    fi
fi

echo "$ICON_DISCONNECTED"
