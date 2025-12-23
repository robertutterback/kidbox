#!/usr/bin/env bash
set -euo pipefail

# Kid kiosk behavior:
# - no Exit option
# - Esc/cancel returns to menu
# - Ctrl+C does nothing

#trap '' INT

KIDBOX_DIR="$HOME/kidbox"
RUNX="$HOME/bin/runx.sh"

SALLY_FILE="$KIDBOX_DIR/typing/sally.txt"
PENNY_FILE="$KIDBOX_DIR/typing/penny.txt"
LOGO_WELCOME="$KIDBOX_DIR/logo/welcome.lg"
CLOCK_SCRIPT="$HOME/bin/clock.sh"
TIMER_SCRIPT="$HOME/bin/timer.sh"
BOOK_PDF="$KIDBOX_DIR/kidbook.pdf"

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
        8 "Read the Book" \
      3>&1 1>&2 2>&3
  ) || {
    # Esc / Cancel: just re-show the menu
    continue
  }

  case "$CHOICE" in
    1) "$RUNX" leafpad "$SALLY_FILE" ;;
    2) "$RUNX" leafpad "$PENNY_FILE" ;;
    3) "$RUNX" tuxpaint ;;
    4) "$RUNX" ucblogo "$LOGO_WELCOME" ;;
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
      "$RUNX" pcbasic
      ;;
    6) "$RUNX" "$CLOCK_SCRIPT" ;;
    7) "$RUNX" "$TIMER_SCRIPT" ;;
    8) "$RUNX" xpdf "$BOOK_PDF" ;;
  esac
done
