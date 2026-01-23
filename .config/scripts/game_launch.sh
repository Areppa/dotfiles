#!/bin/bash

# This script disables 2nd monitor temporarily
# so that games can launch with correct resolution

# Monitor to disable temporarily
MON="DVI-D-1"
# Monitor config: resolution@refreshrate,location,scale
MON_CFG=1680x1050@59.95,1920x0,1
# Time to disable second monitor
TIME=5

echo "Disabling 2nd display..."
notify-send "Disabling $MON temporarily" "It will turn on in $TIME seconds"
hyprctl keyword monitor "${MON}, disable"

sleep $TIME

echo "Enabling $MON"
hyprctl keyword monitor "${MON}, ${MON_CFG}"
