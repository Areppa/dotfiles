#!/bin/bash

# Get the list of available audio sinks, excluding easyeffects_sink
sinks=($(pactl list short sinks | grep -v easyeffects_sink | awk '{print $2}'))

# Get the current default sink
current_sink=$(pactl get-default-sink)

# Find the index of the current sink in the available sinks
current_index=-1
for i in "${!sinks[@]}"; do
    if [[ "${sinks[$i]}" == "$current_sink" ]]; then
        current_index=$i
        break
    fi
done

# If current sink wasn't found (e.g., it's easyeffects_sink), start from 0
if [[ $current_index -eq -1 ]]; then
    current_index=0
else
    # Calculate the next index
    current_index=$(( (current_index + 1) % ${#sinks[@]} ))
fi

# Set the next sink as the default
pactl set-default-sink "${sinks[$current_index]}"

# Output the change
echo "Switched to: ${sinks[$current_index]}"
