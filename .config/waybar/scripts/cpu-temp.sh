#!/usr/bin/env bash

MIN_TEMP=80  # Celsius; set to 0 to always print a valid reading
temps=()

collect() {
    local mode="$1" label_file label input raw

    for label_file in /sys/class/hwmon/hwmon*/temp*_label; do
        [[ -r "$label_file" ]] || continue
        IFS= read -r label < "$label_file"
        input="${label_file%_label}_input"
        [[ -r "$input" ]] || continue

        case "$mode:$label" in
            core:*)
                [[ "$label" =~ ^Core[[:space:]]+[0-9]+$ ]] || continue
                ;;
            tdie:*) [[ "$label" == "Tdie" ]] || continue ;;
            tctl:*) [[ "$label" == "Tctl" ]] || continue ;;
            package:*)
                [[ "$label" =~ ^Package[[:space:]]id[[:space:]]+[0-9]+$ ]] || continue
                ;;
            cpu:*)
                [[ "$label" =~ ^CPU([[:space:]]?[0-9]+)?$ ]] || continue
                ;;
        esac

        IFS= read -r raw < "$input"
        [[ "$raw" =~ ^[0-9]+$ ]] && temps+=("$raw")
    done
}

# Prefer per-core readings; otherwise try package-style sensors.
for mode in core tdie tctl package cpu; do
    temps=()
    collect "$mode"
    ((${#temps[@]})) && break
done

# Fallback for systems that expose CPU temperature as a thermal zone.
if ((${#temps[@]} == 0)); then
    for type_file in /sys/class/thermal/thermal_zone*/type; do
        [[ -r "$type_file" ]] || continue
        IFS= read -r label < "$type_file"
        [[ "$label" =~ [Cc][Pp][Uu] ]] || continue

        input="${type_file%type}temp"
        [[ -r "$input" ]] || continue
        IFS= read -r raw < "$input"
        [[ "$raw" =~ ^[0-9]+$ ]] && temps+=("$raw")
    done
fi

((${#temps[@]})) || exit 1

printf '%s\n' "${temps[@]}" |
    awk -v min="$MIN_TEMP" '{
        sum += $1 / 1000
    } END {
        avg = sum / NR
        if (NR && avg >= min) printf "🔥 %.0f°C\n", avg
    }'
