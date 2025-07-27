#!/bin/bash

# Audio device indices to switch through
audio_device_indices=(0 1)

# Get the list of available audio sinks
sinks=($(pactl list short sinks | awk '{print $2}'))

# Get the current default sink
current_sink=$(pactl get-default-sink)

# Find the index of the current sink in the available sinks
for i in "${!sinks[@]}"; do
    if [[ "${sinks[$i]}" == "$current_sink" ]]; then
        current_index=$i
        break
    fi
done

# Calculate the next index
next_index=$(( (current_index + 1) % ${#audio_device_indices[@]} ))

# Set the next sink as the default using the specified index
pactl set-default-sink "${sinks[${audio_device_indices[$next_index]}]}"

# Output the change
echo "Switched to: ${sinks[${audio_device_indices[$next_index]}]}"
