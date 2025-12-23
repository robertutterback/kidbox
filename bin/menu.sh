#!/usr/bin/env bash
set -euo pipefail

# Kid kiosk behavior:
# - no Exit option
# - Esc/cancel returns to menu
# - Ctrl+C does nothing

#trap '' INT

KIDBOX_DIR="$HOME/kidbox"
LOG_DIR="$HOME/.kidbox-logs"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/$(date +%Y-%m-%d).log"

SALLY_FILE="$KIDBOX_DIR/typing/sally.txt"
PENNY_FILE="$KIDBOX_DIR/typing/penny.txt"
LOGO_WELCOME="$KIDBOX_DIR/logo/welcome.lg"
CLOCK_SCRIPT="$HOME/bin/clock.sh"
TIMER_SCRIPT="$HOME/bin/timer.sh"
STOPWATCH_SCRIPT="$HOME/bin/stopwatch.sh"
BOOK_PDF="$KIDBOX_DIR/kidbook.pdf"

# Function to run X programs with logging
# Usage: run_x <program> [args...]
run_x() {
  if [[ $# -lt 1 ]]; then
    echo "ERROR: run_x requires at least one argument" >&2
    return 2
  fi

  local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$timestamp] Starting: $*" >> "$LOGFILE"

  export KID_APP="$1"
  shift || true
  export KID_ARGS="${*:-}"

  # Start X server and capture output to log
  xinit -- :1 -br -nolisten tcp "vt${XDG_VTNR:-1}" >> "$LOGFILE" 2>&1

  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$timestamp] Finished: $KID_APP" >> "$LOGFILE"
}

while true; do
  CHOICE=$(
    whiptail --title "Girls' Computer" \
      --menu "Choose something to do" 20 70 10 \
        1 "Type Letters (Sally)" \
        2 "Type Letters (Penny)" \
        3 "Draw Pictures" \
        4 "Draw Pictures with Logo Turtle" \
        5 "Write BASIC Programs" \
        6 "Clock" \
        7 "Timer" \
        8 "Stopwatch" \
        9 "Read the Book" \
      3>&1 1>&2 2>&3
  ) || {
    # Esc / Cancel: just re-show the menu
    continue
  }

  case "$CHOICE" in
    1) run_x leafpad "$SALLY_FILE" ;;
    2) run_x leafpad "$PENNY_FILE" ;;
    3) run_x tuxpaint ;;
    4) run_x ucblogo "$LOGO_WELCOME" ;;
    5)
      clear
      echo "PC-BASIC tips:"
      echo "  10 PRINT \"HI\""
      echo "  20 GOTO 10"
      echo "  RUN"
      echo "  LIST"
      echo "  NEW"
      echo
      read -n1 -rsp "Press any key to start BASIC..."
      echo
      run_x pcbasic
      ;;
    6) run_x "$CLOCK_SCRIPT" ;;
    7) run_x "$TIMER_SCRIPT" ;;
    8) run_x "$STOPWATCH_SCRIPT" ;;
    9) run_x evince "$BOOK_PDF" ;;
  esac
done
