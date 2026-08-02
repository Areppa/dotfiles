#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/phone-tether.conf"

# --- Create private config template if missing ---
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<'EOF'
# Private configuration for phone-tether.sh
# Replace the placeholder values with your own and keep this file out of git.

PHONE_BT="__CHANGE_ME__"
HOME_WIFI="__CHANGE_ME__"
HOTSPOT_WIFI="__CHANGE_ME__"
EOF
    echo "Created private config: $CONFIG_FILE"
    echo "Edit it with your real values, then re-run."
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

for var in PHONE_BT HOME_WIFI HOTSPOT_WIFI; do
    if [ -z "${!var:-}" ] || [ "${!var}" = "__CHANGE_ME__" ]; then
        echo "Please set $var in $CONFIG_FILE" >&2
        exit 1
    fi
done

# --- Dependency check ---
declare -A CMD_PKG=(
    [bluetoothctl]=bluez-utils
    [nmcli]=networkmanager
)

missing_pkgs=()
for cmd in "${!CMD_PKG[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing_pkgs+=("${CMD_PKG[$cmd]}")
    fi
done

if [ ${#missing_pkgs[@]} -gt 0 ]; then
    echo "Missing required packages: ${missing_pkgs[*]}"
    read -r -p "Install with pacman? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        sudo pacman -S --needed "${missing_pkgs[@]}"
    else
        echo "Install the missing packages and re-run." >&2
        exit 1
    fi
fi

# --- Service check ---
for svc in bluetooth NetworkManager; do
    if ! systemctl is-active --quiet "$svc"; then
        echo "Service $svc is not running."
        read -r -p "Start and enable $svc? [y/N] " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            sudo systemctl enable --now "$svc"
        else
            echo "Please start $svc and re-run." >&2
            exit 1
        fi
    fi
done

# --- Turn radios on ---
nmcli radio wifi on >/dev/null 2>&1 || true
bluetoothctl power on >/dev/null 2>&1 || true

# --- Connect Bluetooth to phone ---
echo "Connecting Bluetooth to $PHONE_BT ..."
if ! bluetoothctl info "$PHONE_BT" 2>/dev/null | grep -q "Connected: yes"; then
    for _ in {1..15}; do
        bluetoothctl connect "$PHONE_BT" >/dev/null 2>&1 || true
        sleep 1
        if bluetoothctl info "$PHONE_BT" 2>/dev/null | grep -q "Connected: yes"; then
            break
        fi
    done
fi

if ! bluetoothctl info "$PHONE_BT" 2>/dev/null | grep -q "Connected: yes"; then
    echo "Failed to connect Bluetooth to phone." >&2
    exit 1
fi
echo "Bluetooth connected."

# --- Wait for phone hotspot to appear ---
echo "Scanning for hotspot '$HOTSPOT_WIFI' ..."
found=0
for _ in $(seq 1 15); do
    nmcli device wifi list --rescan yes >/dev/null 2>&1 || true
    sleep 2
    if nmcli -t -f SSID device wifi | grep -Fxq "$HOTSPOT_WIFI"; then
        found=1
        break
    fi
done

if [ "$found" -eq 0 ]; then
    echo "Hotspot '$HOTSPOT_WIFI' not found." >&2
    exit 1
fi
echo "Hotspot found."

# --- Check current WiFi connection ---
active_ssid=$(nmcli -t -f ACTIVE,SSID device wifi \
    | awk -F: '$1=="yes"{sub(/^yes:/,""); print; exit}')

if [ "$active_ssid" = "$HOTSPOT_WIFI" ]; then
    echo "Already connected to '$HOTSPOT_WIFI'."
    exit 0
fi

# --- Disconnect current WiFi if any ---
if [ -n "$active_ssid" ]; then
    if [ "$active_ssid" = "$HOME_WIFI" ]; then
        echo "Switching from home WiFi '$HOME_WIFI' to hotspot..."
    else
        echo "Disconnecting current WiFi '$active_ssid'..."
    fi

    wifi_dev=$(nmcli -t -f DEVICE,TYPE,STATE device \
        | awk -F: '$2=="wifi" && $3=="connected"{print $1; exit}')

    [ -n "$wifi_dev" ] && nmcli device disconnect "$wifi_dev"
fi

# --- Connect to hotspot ---
echo "Connecting to '$HOTSPOT_WIFI'..."

if nmcli connection show "$HOTSPOT_WIFI" >/dev/null 2>&1; then
    nmcli connection up "$HOTSPOT_WIFI"
else
    profile=""
    while IFS=: read -r conn ctype; do
        [ "$ctype" = "802-11-wireless" ] || continue
        conn_ssid=$(nmcli -t -f 802-11-wireless.ssid connection show "$conn" 2>/dev/null | cut -d: -f2-)
        if [ "$conn_ssid" = "$HOTSPOT_WIFI" ]; then
            profile=$conn
            break
        fi
    done < <(nmcli -t -f NAME,TYPE connection show)

    if [ -n "$profile" ]; then
        nmcli connection up "$profile"
    else
        nmcli device wifi connect "$HOTSPOT_WIFI"
    fi
fi
