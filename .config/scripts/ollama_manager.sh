#!/usr/bin/env bash
OLLAMA_BIN="/usr/bin/ollama"

# Check if ac power is used:
is_on_ac() {
    [[ -f /sys/class/power_supply/AC/online ]] && [[ $(cat /sys/class/power_supply/AC/online) -eq 1 ]] && return
    for f in /sys/class/power_supply/*/online; do
        name=$(basename "$(dirname "$f")")
        [[ $name == AC* || $name == Mains* || $name == ADP* ]] && [[ $(cat "$f") -eq 1 ]] && return
    done
    command -v upower >/dev/null && upower -i "$(upower -e | grep -E 'line|ac|mains')" 2>/dev/null | grep -q "state:.*online"
}

# Start ollama
start_ollama() {
    if ! pgrep -x ollama >/dev/null; then
        echo "AC detected – starting Ollama..."
        "$OLLAMA_BIN" serve &
        echo $! > /tmp/ollama_pid
    else
        echo "AC detected – Ollama already running."
    fi
}

# Stop ollama
stop_ollama() {
    if pgrep -x ollama >/dev/null; then
        echo "Battery detected – stopping Ollama..."
        kill "$(cat /tmp/ollama_pid)" 2>/dev/null || pkill -x ollama
        rm -f /tmp/ollama_pid
    else
        echo "Battery detected – Ollama already stopped."
    fi
}

# Main loop
prev_state="unknown"
while true; do

    # Check power source
    if is_on_ac; then
        cur_state="AC"
    else
        cur_state="BATTERY"
    fi

    # Check if power source has changed
    if [[ "$cur_state" != "$prev_state" ]]; then
        [[ "$cur_state" == "AC" ]] && echo "Transition: BATTERY → AC" || echo "Transition: AC → BATTERY"
        prev_state="$cur_state"
    fi

    # Control ollama based on power source
    [[ "$cur_state" == "AC" ]] && start_ollama || stop_ollama
    sleep 30
done
