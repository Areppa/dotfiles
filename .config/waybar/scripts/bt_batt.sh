#!/usr/bin/env bash

# Get connected device MAC addresses
mapfile -t devices < <(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}')

[ ${#devices[@]} -eq 0 ] && exit 0

# Map bluez Icon names to Nerd Font icons
icon_for() {
    case "$1" in
        audio-headphones|audio-headset) echo "󰋋" ;;
        audio-card|audio-speaker)       echo "󰓃" ;;
        input-mouse)                    echo "󰍽" ;;
        input-keyboard)                 echo "󰌌" ;;
        input-gaming|input-gamepad)     echo "󰊗" ;;
        input-tablet)                   echo "󰓷" ;;
        phone)                          echo "󰏲" ;;
        computer)                       echo "󰌽" ;;
        camera)                         echo "󰄀" ;;
        video-display)                  echo "󰍹" ;;
        network-wireless|modem)         echo "󰖩" ;;
        printer)                        echo "󰐪" ;;
        scanner)                        echo "󰚫" ;;
        *)                              echo "󰂱" ;;
    esac
}

entries=()

for mac in "${devices[@]}"; do
    info=$(bluetoothctl info "$mac" 2>/dev/null || true)
    [ -z "$info" ] && continue

    echo "$info" | grep -q "Connected: yes" || continue

    battery_line=$(echo "$info" | grep "Battery Percentage:" || true)
    [ -z "$battery_line" ] && continue

    battery=$(echo "$battery_line" | grep -oE '0x[0-9a-fA-F]+|[0-9]+' | tail -n1)
    [ -z "$battery" ] && continue
    battery=$((battery))

    icon_name=$(echo "$info" | grep "Icon:" | awk '{print $2}')
    icon=$(icon_for "$icon_name")

    entries+=("$icon $battery%")
done

[ ${#entries[@]} -eq 0 ] && exit 0

text=$(printf "%s, " "${entries[@]}" | sed 's/, $//')
echo "󰂯: $text"
