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

# Show countdown in a large xterm window
xterm -maximized -fa 'Monospace' -fs 48 -e bash -c "
  secs=$secs
  while [ \$secs -ge 0 ]; do
    clear
    echo
    echo
    echo '        TIMER'
    echo
    printf '        %02d:%02d\n' \$((secs/60)) \$((secs%60))
    echo
    echo
    echo '   Press Ctrl+C to stop.'
    sleep 1
    secs=\$((secs - 1))
  done

  # Alarm sound (pick one that exists on Pi OS)
  for wav in /usr/share/sounds/alsa/Front_Center.wav /usr/share/sounds/alsa/Noise.wav; do
    if [ -f \"\$wav\" ]; then
      aplay \"\$wav\" >/dev/null 2>&1 || true
      aplay \"\$wav\" >/dev/null 2>&1 || true
      sleep 2
      exit 0
    fi
  done

  # Fallback: terminal bell
  printf '\a\a\a'
  sleep 2
"
