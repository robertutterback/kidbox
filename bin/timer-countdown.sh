#!/usr/bin/env bash
set -euo pipefail

# This script is called by timer.sh with the number of seconds as an argument
if [[ $# -lt 1 ]]; then
  echo "Usage: timer-countdown.sh <seconds>"
  exit 1
fi

secs=$1

# Determine content directory (installed vs development)
if [ -d "$HOME/kidbox" ]; then
  CONTENT_DIR="$HOME/kidbox"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CONTENT_DIR="$SCRIPT_DIR/../content"
fi

# Start background timer music if available
TIMER_SOUND="$CONTENT_DIR/timer.mp3"
MUSIC_PID=""
if [ -f "$TIMER_SOUND" ] && command -v mpg123 >/dev/null 2>&1; then
  mpg123 -q --loop -1 "$TIMER_SOUND" &
  MUSIC_PID=$!
fi

# Trap to clean up music on exit
trap "kill $MUSIC_PID 2>/dev/null || true" EXIT

while [ $secs -ge 0 ]; do
  clear
  echo
  echo
  echo '        TIMER'
  echo
  printf '        %02d:%02d\n' $((secs/60)) $((secs%60))
  echo
  echo
  echo '   Press Ctrl+C to stop.'
  sleep 1
  secs=$((secs - 1))
done

# Clear screen and show TIME'S UP! message
clear
echo
echo
echo '   ⏰  TIME'"'"'S UP!  ⏰'
echo
echo

# Stop timer music
kill $MUSIC_PID 2>/dev/null || true

# Play alarm sound (looping)
ALARM_SOUND="$CONTENT_DIR/alarm.mp3"
ALARM_PID=""
if [ -f "$TIMER_SOUND" ] && command -v mpg123 >/dev/null 2>&1; then
    mpg123 -q --loop -1 "$ALARM_SOUND" &
    ALARM_PID=$!
fi

# Update trap to kill alarm on exit
trap "kill $ALARM_PID 2>/dev/null || true" EXIT

# Let alarm play for 60 seconds then exit
echo '   Press Ctrl+C to stop.'
sleep 60
