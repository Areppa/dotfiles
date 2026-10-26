#!/usr/bin/env bash
# Usage: stats-short.sh [-C] [-M]
# -C  print CPU only
# -M  print Memory only

CPU_THRESHOLD=50
RAM_THRESHOLD=80

print_cpu=0
print_mem=0

for arg in "$@"; do
  case "$arg" in
    -C) print_cpu=1 ;;
    -M) print_mem=1 ;;
  esac
done

# If no flags are given, print both.
if (( ! print_cpu && ! print_mem )); then
  print_cpu=1
  print_mem=1
fi

get_cpu() {
  local user nice system idle iowait irq softirq steal
  local total1 idle1 total2 idle2 dt idt cpu

  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  total1=$((user + nice + system + idle + iowait + irq + softirq + steal))
  idle1=$((idle + iowait))

  sleep 0.25

  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  total2=$((user + nice + system + idle + iowait + irq + softirq + steal))
  idle2=$((idle + iowait))

  dt=$((total2 - total1))
  idt=$((idle2 - idle1))

  if (( dt > 0 )); then
    cpu=$((100 * (dt - idt) / dt))
  else
    cpu=0
  fi

  if (( cpu > CPU_THRESHOLD )); then
    printf ' %d%%' "$cpu"
  fi
}

get_mem() {
  local key value _
  local mem_total_kb=0 mem_avail_kb=0 mem_used_kb mem_percent whole frac

  while read -r key value _; do
    case "$key" in
      MemTotal:)     mem_total_kb=$value ;;
      MemAvailable:) mem_avail_kb=$value ;;
    esac
  done < /proc/meminfo

  (( mem_total_kb > 0 )) || return

  mem_used_kb=$((mem_total_kb - mem_avail_kb))
  mem_percent=$((100 * mem_used_kb / mem_total_kb))

  if (( mem_percent > RAM_THRESHOLD )); then
    whole=$((mem_used_kb / 1048576))
    frac=$(((mem_used_kb % 1048576) * 10 / 1048576))
    printf ' %d.%dG' "$whole" "$frac"
  fi
}

out=""

if (( print_cpu )); then
  out="$(get_cpu)"
fi

if (( print_mem )); then
  mem_out="$(get_mem)"
  if [[ -n $out && -n $mem_out ]]; then
    out+=" | $mem_out"
  elif [[ -n $mem_out ]]; then
    out=$mem_out
  fi
fi

if [[ -n $out ]]; then
  printf '%s\n' "$out"
fi
