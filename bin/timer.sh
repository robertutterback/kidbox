#!/usr/bin/env bash
set -euo pipefail

# Ask for minutes. Cancel returns to menu.
mins="$(zenity --entry \
  --title="Timer" \
  --text="How many minutes?" \
  --entry-text="5")" || exit 0

# Validate input is a positive number
if ! [[ "$mins" =~ ^[0-9]+$ ]] || [ "$mins" -lt 1 ]; then
  zenity --error --text="Please enter a number greater than 0"
  exit 1
fi

secs=$((mins * 60))

# Run countdown script in xterm
xterm -maximized -fa 'Monospace' -fs 48 -e "$HOME/bin/timer-countdown.sh" "$secs"
