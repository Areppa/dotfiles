#!/bin/bash

# TODO
# - Run ansible playbook on the system automatically on startup

# Remove specific flatpaks automatically
flatpak remove org.gnome.Mines org.gnome.Mahjongg -y

# Upgrade flatpaks
#flatpak upgrade -y
