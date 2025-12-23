#!/usr/bin/env bash
set -euo pipefail

# Fullscreen xterm that will contain both clocks
# The xterm runs tty-clock (digital), and we launch xclock (analog) on top
xterm -maximized -fa 'Monospace' -fs 16 -e bash -c '
  # Launch analog clock as background process (floats on top of xterm)
  # Position it on the left side
  xclock -analog -update 1 -geometry 400x400+100+150 &
  XCLOCK_PID=$!

  # Trap exit to clean up xclock
  trap "kill $XCLOCK_PID 2>/dev/null || true" EXIT

  # Run digital clock in the xterm (centered)
  # -C 6 = cyan, -s = show seconds, -c = center
  exec tty-clock -sC 6 -c
'
