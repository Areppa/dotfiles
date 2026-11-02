#!/usr/bin/env bash

# Settings
MIN_TEMP=70          # Celsius; set to 0 to always show a valid reading
HISTORY_COUNT=5       # Number of measurements to average

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/waybar-network-${UID}"
HISTORY_FILE="$STATE_DIR/cpu-temp-history"
LOCK_FILE="$STATE_DIR/cpu-temp.lock"

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

# Fall back to thermal zones that expose a CPU temperature.
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

# Ensure HISTORY_COUNT is a positive integer and avoid octal interpretation.
[[ "$HISTORY_COUNT" =~ ^[1-9][0-9]*$ ]] || HISTORY_COUNT=1
HISTORY_COUNT=$((10#$HISTORY_COUNT))

# Average this run's sensor readings in millidegrees, retaining precision.
SAMPLE_MC=$(printf '%s\n' "${temps[@]}" | awk '{
    sum += $1
} END {
    if (NR) printf "%.6f", sum / NR
}')
[[ -n "$SAMPLE_MC" ]] || exit 1

mkdir -p "$STATE_DIR" || exit 1
chmod 700 "$STATE_DIR" 2>/dev/null || :

# Prevent overlapping CPU-temp runs from writing the history simultaneously.
exec 9>"$LOCK_FILE"
flock 9

# Keep the newest HISTORY_COUNT - 1 samples, then add this run's sample.
HISTORY_TMP="${HISTORY_FILE}.tmp"
{
    tail -n "$((HISTORY_COUNT - 1))" "$HISTORY_FILE" 2>/dev/null || :
    printf '%s\n' "$SAMPLE_MC"
} > "$HISTORY_TMP" || exit 1
mv "$HISTORY_TMP" "$HISTORY_FILE" || exit 1

# Calculate the rolling minimum, average, and maximum.
# Round only the displayed values; use the unrounded average for the threshold.
read -r MIN_ROUNDED AVG_ROUNDED MAX_ROUNDED CLASS < <(
    awk -v min="$MIN_TEMP" '{
        total += $1
        count++

        if (count == 1 || $1 < lowest) lowest = $1
        if (count == 1 || $1 > highest) highest = $1
    } END {
        if (count) {
            avg_c = total / count / 1000
            min_c = lowest / 1000
            max_c = highest / 1000

            class = (avg_c >= min) ? "hot" : "normal"
            printf "%.0f %.0f %.0f %s\n", min_c, avg_c, max_c, class
        }
    }' "$HISTORY_FILE"
)

[[ -n "$AVG_ROUNDED" ]] || exit 1

DISPLAY=""
if [[ "$CLASS" == "hot" ]]; then
    DISPLAY="🔥 ${AVG_ROUNDED}°C"
fi

TOOLTIP=$(printf 'Min: %s°C\nAvg: %s°C\nMax: %s°C' \
    "$MIN_ROUNDED" "$AVG_ROUNDED" "$MAX_ROUNDED")

# Output JSON for Waybar's return-type: "json".
jq -cn \
    --arg text "$DISPLAY" \
    --arg tooltip "$TOOLTIP" \
    --arg class "$CLASS" \
    '{text: $text, tooltip: $tooltip, class: $class}'
