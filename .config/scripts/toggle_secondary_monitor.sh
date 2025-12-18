#!/usr/bin/env bash
# toggle-monitor.sh <1|0>
MON="DVI-D-1"
[ "$1" = 1 ] && hyprctl keyword monitor "${MON}, 1680x1050@59.95,1920x0,1" && exit $?
[ "$1" = 0 ] && hyprctl keyword monitor "${MON}, disable" && exit $?
echo "Usage: $0 1|0" >&2
exit 2
