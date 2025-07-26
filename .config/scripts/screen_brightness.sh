#!/bin/bash

# Requirements
#
# Install ddcutil
# modprobe i2c-dev
# 
# Get display i2c bus numbers:
# ddcutil detect | grep I2C
#
# How to run:
# ./screen_brightness.sh X
# where X is the brightness of the screens
#


# Check if the script has the required argument
if [ -z "$1" ]; then
    echo "Usage: $0 <brightness_percentage>"
    exit 1
fi

# The brightness value from the first argument
BRIGHTNESS=$1

# List of I2C bus numbers for connected monitors (replace with your actual I2C bus numbers)
BUS_LIST=("3" "7")

# Validate the brightness percentage
if [ "$BRIGHTNESS" -lt 0 ] || [ "$BRIGHTNESS" -gt 100 ]; then
    echo "Brightness percentage should be between 0 and 100."
    exit 1
fi

# Loop through each screen and set the brightness
for BUS in "${BUS_LIST[@]}"; do
    echo "Setting brightness to $BRIGHTNESS% on I2C bus $BUS"
    ddcutil --bus=$BUS setvcp 10 "$BRIGHTNESS"
done

echo "Brightness set."
