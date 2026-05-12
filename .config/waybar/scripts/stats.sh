#!/usr/bin/env bash
# stats-short.sh - compact CPU & RAM for Waybar (icons)
# Usage: stats-short.sh [-C] [-M] [--cpu-threshold N] [--mem-threshold N]
#  -C                      print CPU only
#  -M                      print Memory only
#  --cpu-threshold N       only show CPU if above N%
#  --mem-threshold N       only show Memory if above N%

print_cpu=false
print_mem=false
cpu_threshold=0
mem_threshold=0

# parse flags
i=1
for arg in "$@"; do
  case "$arg" in
    -C) print_cpu=true ;;
    -M) print_mem=true ;;
    --cpu-threshold)
      i=$((i + 1))
      eval "cpu_threshold=\${$i}"
      ;;
    --mem-threshold)
      i=$((i + 1))
      eval "mem_threshold=\${$i}"
      ;;
    *) ;;
  esac
  i=$((i + 1))
done

# if no flags given, print both
if ! $print_cpu && ! $print_mem; then
  print_cpu=true
  print_mem=true
fi

# CPU usage (sample /proc/stat)
get_cpu() {
  read -r _ u n s i w irq soft steal _ < /proc/stat
  total1=$((u + n + s + i + w + irq + soft + steal)); idle1=$i
  sleep 0.25
  read -r _ u n s i w irq soft steal _ < /proc/stat
  total2=$((u + n + s + i + w + irq + soft + steal)); idle2=$i
  dt=$((total2 - total1)); idt=$((idle2 - idle1))
  if [ "$dt" -gt 0 ]; then
    cpu=$(( (100 * (dt - idt)) / dt ))
  else
    cpu=0
  fi

  # Check threshold
  if [ "$cpu" -gt "$cpu_threshold" ]; then
    printf " %d%%" "$cpu"
  fi
}

# Memory usage (kB)
get_mem() {
  mem_total_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
  mem_avail_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
  mem_used_kb=$((mem_total_kb - mem_avail_kb))

  # Calculate percentage
  mem_percent=$((100 * mem_used_kb / mem_total_kb))

  # Check threshold
  if [ "$mem_percent" -gt "$mem_threshold" ]; then
    # GiB with one decimal
    whole=$(( mem_used_kb / 1048576 ))
    frac=$(( (mem_used_kb % 1048576) * 10 / 1048576 ))
    printf " %d.%dG" "$whole" "$frac"
  fi
}

out=""
if $print_cpu; then
  out="$(get_cpu)"
fi
if $print_mem; then
  mem_out="$(get_mem)"
  if [ -n "$out" ] && [ -n "$mem_out" ]; then
    out="$out | $mem_out"
  elif [ -n "$mem_out" ]; then
    out="$mem_out"
  fi
fi

if [ -n "$out" ]; then
  printf "%s\n" "$out"
fi
