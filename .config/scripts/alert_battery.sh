#!/bin/sh
# Sources: https://ejmastnak.com/tutorials/arch/battery-alert/

threshold=20

acpi -b | awk -F'[,:%]' '{
  # trim leading/trailing spaces from fields 2 and 3, print only first battery line
  gsub(/^[ \t]+|[ \t]+$/, "", $2)
  gsub(/^[ \t]+|[ \t]+$/, "", $3)
  print $2, $3
  exit
}' | {
  read -r status capacity

  if [ "$status" = "Discharging" ] && [ "$capacity" -lt "$threshold" ]; then
    notify-send -t 300000 "Low battery" "Please charge your battery!"
  fi
}
