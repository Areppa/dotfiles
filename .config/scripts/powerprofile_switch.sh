#!/usr/bin/env bash

# fixed options
options=("power-saver" "balanced" "performance")

# get current profile (powerprofilesctl marks current with '*' or '(current)')
current=$(powerprofilesctl list 2>/dev/null | sed -nE 's/^\s*\*\s*(.*)|^\s*(.*)\s+\(current\)/\1\2/p' | tr -d ' ' || true)

# build rofi input, mark current with ▸ (cosmetic)
printf '%s\n' "${options[@]}" | awk -v cur="$current" '{print ($0==cur ? "▸ "$0 : "  "$0)}' \
  | rofi -dmenu -p "Power profile:" -mesg "Current: ${current:-unknown}" \
  | sed 's/^[[:space:]]*▸[[:space:]]*//' \
  | { read -r choice || exit 0
      [ -z "$choice" ] && exit 0
      powerprofilesctl set "$choice" && notify-send "Power profile" "Switched to: $choice"
    }
