#!/usr/bin/env bash
set -euo pipefail

if spicetify update | grep -q "is up-to-date"; then
  echo "Spicetify is already up to date."
  exit 0
fi

echo "Updating Spicetify..."

spicetify upgrade
spicetify apply

echo "Done."
