#!/bin/bash

SCRIPT=$HOME/dotfiles/.config/scripts/toggle_secondary_monitor.sh
TIME=30

echo "Disabling 2nd display..."
notify-send "Disabling 2nd display for $TIME seconds"
$SCRIPT 0

sleep $TIME

echo "Enabling 2nd display..."
$SCRIPT 1
