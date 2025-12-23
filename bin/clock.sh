#!/usr/bin/env bash
set -euo pipefail

# Fullscreen xterm that will contain both clocks
# The xterm shows digital time on right, cairo-clock (analog) floats on left
xterm -maximized -fa 'Monospace' -fs 48 -e bash -c '
  # Launch analog clock on left side
  # Large clock for 1920x1080 display, positioned at left
  cairo-clock --width=700 --height=700 &
  CLOCK_PID=$!

  # Trap exit to clean up cairo-clock
  trap "kill $CLOCK_PID 2>/dev/null || true" EXIT

  # Simple digital clock display on the right
  # Cyan color, large text, positioned to avoid analog clock
  tput civis  # hide cursor
  while true; do
    TIME=$(date "+%I:%M:%S %p")
    DATE=$(date "+%A, %B %d, %Y")

    tput clear
    tput setaf 6  # cyan
    tput cup 12 80   # position: row 12, column 80 (right side)
    echo "$TIME"
    tput cup 14 80
    echo "$DATE"

    sleep 1
  done
'
