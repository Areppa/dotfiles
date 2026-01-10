#!/bin/bash

SCRIPT=$HOME/dotfiles/.config/scripts/toggle_secondary_monitor.sh

echo "Disabling 2nd display..."
$SCRIPT 0

sleep 30

echo "Enabling 2nd display..."
$SCRIPT 1
