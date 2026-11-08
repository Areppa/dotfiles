#!/usr/bin/env bash

read_num() {
    local value
    [[ -r "$1" ]] || return 1
    IFS= read -r value < "$1"
    [[ "$value" =~ ^-?[0-9]+$ ]] || return 1
    printf '%s' "$value"
}

battery=""
for path in /sys/class/power_supply/BAT*; do
    if [[ -r "$path/capacity" ]]; then
        battery="$path"
        break
    fi
done

if [[ -z "$battery" ]]; then
    printf '{"text":""}\n'
    exit 0
fi

level=$(read_num "$battery/capacity") || level=0
status="Unknown"
if [[ -r "$battery/status" ]]; then
    IFS= read -r status < "$battery/status"
fi

charger_connected=false
for path in /sys/class/power_supply/*; do
    if [[ -r "$path/online" ]] && [[ "$(read_num "$path/online")" == "1" ]]; then
        charger_connected=true
        break
    fi
done

if "$charger_connected"; then
    class="plugged"
    if [[ "$status" == "Charging" ]]; then
        icon="⚡"
        battery_summary="Charging: ${level}%"
    else
        icon="󰁹"
        battery_summary="Maintaining: ${level}%"
    fi
else
    if (( level >= 95 )); then icon="󰁹"
    elif (( level >= 85 )); then icon="󰂂"
    elif (( level >= 75 )); then icon="󰂁"
    elif (( level >= 65 )); then icon="󰂀"
    elif (( level >= 55 )); then icon="󰁿"
    elif (( level >= 45 )); then icon="󰁾"
    elif (( level >= 35 )); then icon="󰁽"
    elif (( level >= 25 )); then icon="󰁼"
    elif (( level >= 15 )); then icon="󰁻"
    else icon="󰁺"
    fi
    class="unplugged"
    battery_summary="Discharging: ${level}%"
fi

# Power is in microwatts; derive it from current and voltage if unavailable.
power_uw=$(read_num "$battery/power_now") || power_uw=0
(( power_uw < 0 )) && power_uw=$((-power_uw))

current_ua=$(read_num "$battery/current_now") || current_ua=0
(( current_ua < 0 )) && current_ua=$((-current_ua))

voltage_uv=$(read_num "$battery/voltage_now") || voltage_uv=0

if (( power_uw == 0 && current_ua > 0 && voltage_uv > 0 )); then
    power_uw=$(awk -v i="$current_ua" -v v="$voltage_uv" \
        'BEGIN { printf "%.0f", (i * v) / 1000000 }')
fi

power_w="- W"
if (( power_uw > 0 )); then
    power_w=$(awk -v p="$power_uw" 'BEGIN { printf "%.1f W", p / 1000000 }')
fi

voltage="- W"
if (( voltage_uv > 0 )); then
    voltage=$(awk -v v="$voltage_uv" 'BEGIN { printf "%.2f V", v / 1000000 }')
fi

if "$charger_connected"; then
    time_label="Time to full"
else
    time_label="Time to empty"
fi
time_left="∞"

if [[ "$status" == "Charging" || "$status" == "Discharging" ]]; then
    energy_now=$(read_num "$battery/energy_now") || energy_now=0
    energy_full=$(read_num "$battery/energy_full") || energy_full=0
    estimate_available=false

    if (( power_uw > 0 && energy_full > 0 )); then
        if [[ "$status" == "Charging" ]]; then
            remaining=$((energy_full - energy_now))
        else
            remaining=$energy_now
        fi
        (( remaining < 0 )) && remaining=0

        minutes=$(awk -v e="$remaining" -v p="$power_uw" \
            'BEGIN { if (p > 0) printf "%d", (e * 60 / p) + 0.5 }')
        estimate_available=true
    else
        charge_now=$(read_num "$battery/charge_now") || charge_now=0
        charge_full=$(read_num "$battery/charge_full") || charge_full=0

        if (( current_ua > 0 && charge_full > 0 )); then
            if [[ "$status" == "Charging" ]]; then
                remaining=$((charge_full - charge_now))
            else
                remaining=$charge_now
            fi
            (( remaining < 0 )) && remaining=0

            minutes=$(awk -v c="$remaining" -v i="$current_ua" \
                'BEGIN { if (i > 0) printf "%d", (c * 60 / i) + 0.5 }')
            estimate_available=true
        fi
    fi

    if "$estimate_available"; then
        printf -v time_left '%02d:%02d' "$((minutes / 60))" "$((minutes % 60))"
    fi
fi

tooltip="${battery_summary}\\n${time_label}: ${time_left}\\n\\n"
tooltip+="Battery voltage: $voltage\\n"
tooltip+="Battery power: $power_w"

if (( current_ua > 0 )); then
    current=$(awk -v i="$current_ua" 'BEGIN { printf "%.2f A", i / 1000000 }')
    tooltip+="\\nBattery current: $current"
fi

temp=$(read_num "$battery/temp") || temp=""
if [[ -n "$temp" ]]; then
    temperature=$(awk -v t="$temp" 'BEGIN { printf "%.1f °C", t / 10 }')
    tooltip+="\\nTemperature: $temperature"
fi

printf '{"text":"%s %s%%","tooltip":"%s","class":"%s"}\n' \
    "$icon" "$level" "$tooltip" "$class"
