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

while true; do
  CHOICE=$(
    whiptail --title "Girls' Computer" \
      --menu "Choose something to do" 20 70 10 \
        1 "Type letters (Sally)" \
        2 "Type letters (Penny)" \
        3 "Draw pictures (Tux Paint)" \
        4 "Logo turtle (UCBLogo)" \
        5 "BASIC programming (PC-BASIC)" \
      3>&1 1>&2 2>&3
  ) || { 
    # Esc / Cancel: just re-show the menu
    continue
  }

  case "$CHOICE" in
    1) "$RUNX" leafpad "$SALLY_FILE" ;;
    2) "$RUNX" leafpad "$PENNY_FILE" ;;
    3) "$RUNX" tuxpaint ;;
    4)
      clear
      echo "Logo tips:"
      echo "  TRY:  FD 50"
      echo "  TRY:  RT 90"
      echo "  TRY:  REPEAT 4 [FD 50 RT 90]"
      echo
      echo "Optional:"
      echo "  load \"$LOGO_WELCOME\""
      echo
      read -n1 -rsp "Press any key to start Logo..."
      echo
      "$RUNX" ucblogo
      ;;
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
      pcbasic
      ;;
  esac
done
