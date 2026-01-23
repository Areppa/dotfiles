#!/bin/bash

# Hyprland‑Steam monitor toggle
# -------------------------------------------------
# Temporarily disables the secondary monitor to ensure
# games launch at their intended resolution.
# Compatible with Hyprland compositors and Steam.

# Settings:
MON=DVI-D-1                             # Monitor to disable temporarily
MON_CFG=1680x1050@59.95,1920x0,1        # 2nd monitor config: resolution@refresh_rate,location,scale
TIMEOUT=30                              # Timeout if this script doesn't detect a game launch
GAME_CLASS_REGEX='^steam_app_[0-9]+$'   # Regex for the game class

# Helper function to get the active window class
get_active_class() {
    hyprctl activewindow | awk -F': ' '/^\s*class:/{print $2; exit}'
}

# Disabling the second display
echo "Disabling $MON..."
notify-send "Disabling $MON temporarily" "It will be re‑enabled after $TIMEOUT seconds or when the game launches."
hyprctl keyword monitor "${MON},disable"

# Waiting for the game to launch
elapsed=0
while (( elapsed < TIMEOUT )); do
    # Get the active window class and trim whitespace/newlines
    class=$(get_active_class | tr -d '[:space:]')

    # IMPORTANT: do NOT quote $GAME_CLASS_REGEX here
    if [[ $class =~ $GAME_CLASS_REGEX ]]; then
        echo "Detected game window: $class"
        break
    fi

    sleep 1
    (( elapsed++ ))
done

# Adding a small delay for the game to launch properly
sleep 3

# Enabling the second monitor
echo "Re‑enabling $MON..."
hyprctl keyword monitor "${MON},${MON_CFG}"
notify-send "Re‑enabled $MON" "Monitor restored after ${elapsed}s"
