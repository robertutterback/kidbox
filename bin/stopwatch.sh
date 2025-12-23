#!/usr/bin/env bash
set -euo pipefail

# Show stopwatch in a large fullscreen xterm
xterm -maximized -fa 'Monospace' -fs 48 -e bash -c "
  secs=0

  while true; do
    clear
    echo
    echo
    echo '      STOPWATCH'
    echo

    # Calculate hours, minutes, seconds
    hours=\$((secs / 3600))
    mins=\$((secs % 3600 / 60))
    s=\$((secs % 60))

    # Display time (show hours only if > 0)
    if [ \$hours -gt 0 ]; then
      printf '      %02d:%02d:%02d\n' \$hours \$mins \$s
    else
      printf '      %02d:%02d\n' \$mins \$s
    fi

    echo
    echo
    echo '   Press Ctrl+C to stop.'

    sleep 1
    secs=\$((secs + 1))
  done
"
