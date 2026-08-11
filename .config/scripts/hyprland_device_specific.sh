#!/usr/bin/env bash
set -euo pipefail

src="$HOME/.config/hypr/hosts/${HOSTNAME}.lua"
dst="$HOME/dotfiles/.config/hypr/hyprConf/localconfig.lua"

mkdir -p "$(dirname "$dst")"

ln -sfn "$src" "$dst"
