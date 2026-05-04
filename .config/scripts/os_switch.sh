#!/bin/bash

# MUST BE RUN AS ROOT
# Script that boots into other OS temporarily (using efibootmgr)
# Usage: ./os_switch.sh [OS_NAME]
# Example: ./os_switch.sh Windows

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Requesting sudo..."
    exec sudo "$0" "$@"
    exit 1
fi

# Parse efibootmgr output
declare -a boot_options=()
declare -a boot_numbers=()

while IFS= read -r line; do
    # Match lines like: Boot0001* Limine ...
    if [[ $line =~ ^Boot([0-9A-Fa-f]+)\*[[:space:]]+([^[:space:]].+) ]]; then
        boot_num="${BASH_REMATCH[1]}"
        boot_name="${BASH_REMATCH[2]}"
        # Get just the part before the tab character
        boot_name="${boot_name%%$'\t'*}"

        boot_numbers+=("$boot_num")
        boot_options+=("$boot_name")
    fi
done < <(efibootmgr)

# Check if we found any boot options
if [[ ${#boot_options[@]} -eq 0 ]]; then
    echo "No boot options found"
    exit 1
fi

# If parameter provided, try to find matching OS
if [[ -n "$1" ]]; then
    selected_idx=-1
    for i in "${!boot_options[@]}"; do
        if [[ "${boot_options[$i]}" == *"$1"* ]]; then
            selected_idx=$i
            break
        fi
    done

    if [[ $selected_idx -eq -1 ]]; then
        echo "Error: OS matching '$1' not found"
        echo ""
        echo "Available boot options:"
        for i in "${!boot_options[@]}"; do
            echo "  - ${boot_options[$i]}"
        done
        exit 1
    fi

    selected_boot="${boot_numbers[$selected_idx]}"
    echo "Booting into: ${boot_options[$selected_idx]} (Boot$selected_boot)"
    efibootmgr -n "$selected_boot"
    echo "Rebooting..."
    reboot
else
    # Display menu and get user selection
    echo "Select OS to boot into:"
    select choice in "${boot_options[@]}"; do
        if [[ -n "$choice" ]]; then
            idx=$((REPLY - 1))
            selected_boot="${boot_numbers[$idx]}"
            echo "Booting into: $choice (Boot$selected_boot)"
            efibootmgr -n "$selected_boot"
            echo "Rebooting..."
            reboot
            break
        else
            echo "Invalid selection"
            exit 1
        fi
    done
fi
