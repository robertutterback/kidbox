#!/usr/bin/env bash
set -euo pipefail

# Kid kiosk behavior:
# - no Exit option
# - Esc/cancel returns to menu
# - Ctrl+C does nothing
#
# Use --dev flag for local testing (adds Exit option, allows Ctrl+C)

DEV_MODE=false
if [[ "${1:-}" == "--dev" ]]; then
  DEV_MODE=true
fi

if [[ "$DEV_MODE" == false ]]; then
  trap '' INT
fi

# Set volume to 100% at startup
amixer -q sset Master 100% unmute 2>/dev/null || true
amixer -q sset PCM 100% unmute 2>/dev/null || true

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
  if [[ "$DEV_MODE" == true ]]; then
    MENU_TITLE="Girls' Computer [DEV MODE]"
    MENU_ITEMS=(
      1 "Type Letters (Sally)"
      2 "Type Letters (Penny)"
      3 "Draw Pictures"
      4 "Draw Pictures with Logo Turtle"
      5 "Write BASIC Programs"
      6 "Clock"
      7 "Timer"
      8 "Stopwatch"
      9 "Read the Book"
      10 "Shutdown Computer"
      0 "Exit Menu"
    )
  else
    MENU_TITLE="Girls' Computer"
    MENU_ITEMS=(
      1 "Type Letters (Sally)"
      2 "Type Letters (Penny)"
      3 "Draw Pictures"
      4 "Draw Pictures with Logo Turtle"
      5 "Write BASIC Programs"
      6 "Clock"
      7 "Timer"
      8 "Stopwatch"
      9 "Read the Book"
      10 "Shutdown Computer"
    )
  fi

  CHOICE=$(
    whiptail --title "$MENU_TITLE" \
      --menu "Choose something to do" 20 70 11 \
        "${MENU_ITEMS[@]}" \
      3>&1 1>&2 2>&3
  ) || {
    # Esc / Cancel: exit in dev mode, re-show menu otherwise
    if [[ "$DEV_MODE" == true ]]; then
      exit 0
    fi
    continue
  }

  case "$CHOICE" in
    1) run_x leafpad "$SALLY_FILE" ;;
    2) run_x leafpad "$PENNY_FILE" ;;
    3) run_x tuxpaint ;;
    4) run_x ucblogo "$LOGO_WELCOME" ;;
    5) run_x pcbasic ;;
    6) run_x "$CLOCK_SCRIPT" ;;
    7) run_x "$TIMER_SCRIPT" ;;
    8) run_x "$STOPWATCH_SCRIPT" ;;
    9) run_x chromium-browser --kiosk --app="file://$BOOK_PDF" ;;
    10) sudo shutdown -h now ;;
    0) exit 0 ;;
  esac
done
