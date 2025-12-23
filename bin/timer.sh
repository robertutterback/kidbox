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

  # Start background timer music if available
  TIMER_SOUND=\"\$HOME/kidbox/timer.mp3\"
  MUSIC_PID=\"\"
  if [ -f \"\$TIMER_SOUND\" ] && command -v mpg123 >/dev/null 2>&1; then
    mpg123 -q -l 0 \"\$TIMER_SOUND\" >/dev/null 2>&1 &
    MUSIC_PID=\$!
  fi

  # Trap to clean up music on exit
  trap \"kill \$MUSIC_PID 2>/dev/null || true\" EXIT

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

  # Clear screen and show TIME'S UP! message
  clear
  echo
  echo
  echo '   ⏰  TIME'"'"'S UP!  ⏰'
  echo
  echo

  # Play alarm sound (try custom sound first, then fallback)
  ALARM_SOUND=\"\$HOME/kidbox/alarm.mp3\"
  if [ -f \"\$ALARM_SOUND\" ] && command -v mpg123 >/dev/null 2>&1; then
    mpg123 -q -l 0 \"\$ALARM_SOUND\" &
  elif [ -f \"\$ALARM_SOUND\" ] && command -v ffplay >/dev/null 2>&1; then
    ffplay -nodisp -loop 0 -v quiet \"\$ALARM_SOUND\" &
  else
    # Fallback: system sounds or beep
    for wav in /usr/share/sounds/alsa/Front_Center.wav /usr/share/sounds/alsa/Noise.wav; do
      if [ -f \"\$wav\" ]; then
        aplay \"\$wav\" >/dev/null 2>&1 || true
        aplay \"\$wav\" >/dev/null 2>&1 || true
        break
      fi
    done
    printf '\a\a\a'
  fi

  # Visual popup notification
  zenity --info --title='Timer' --text='⏰ TIME'"'"'S UP! ⏰' --width=300 &

  # Wait a bit for sound to finish
  sleep 3
"
