#!/bin/bash

# Remove specific apps
source ~/.config/scripts/startup.sh

# Update Flatpaks
flatpak update -y

# List user installed pacman apps and save it to txt file
pacman -Qqe > ~/Programs/Backup/pacman/$HOSTNAME\_apps.txt
echo Saved apps list to: $HOSTNAME\_apps.txt