#!/usr/bin/env bash
set -euo pipefail

# kidbox-power-menu.sh
# Shows a simple power menu when the power button is pressed (short press)
# This script is called by kidbox-power-watch.service
#
# Menu options:
#   - Shutdown: systemctl poweroff
#   - Reboot: systemctl reboot
#   - Cancel: exit (return to current activity)
#
# The menu is displayed on VT2 (a dedicated, otherwise unused VT) to avoid
# conflicting with the main menu on VT1 for keyboard input.

# Required when running from systemd (no terminal environment)
export TERM=linux

# Blue theme for whiptail
export NEWT_COLORS='
root=white,blue
window=white,blue
border=white,blue
shadow=white,black
title=white,blue
textbox=white,blue
listbox=white,blue
actlistbox=black,lightgray
button=black,lightgray
actbutton=white,blue
helpline=white,blue
roottext=white,blue
entry=black,lightgray
label=white,blue
'

# Remember which VT we're on so we can return on Cancel
ORIG_VT=$(cat /sys/class/tty/tty0/active 2>/dev/null | grep -o '[0-9]*$') || ORIG_VT=""

# Switch to VT2 (dedicated for power menu, avoids input conflict with main menu on VT1)
chvt 2

# Connect all fds to tty2 so whiptail can render and read input.
# (When launched from systemd, there is no controlling terminal.)
exec </dev/tty2 >/dev/tty2 2>&1

# Show power menu on tty2
CHOICE=$(
  whiptail --title "Power Button" \
    --menu "What would you like to do?" 12 50 3 \
      1 "Shutdown" \
      2 "Reboot" \
      3 "Cancel" \
    3>&1 1>&2 2>&3
) || {
  # User pressed Esc - return to original VT
  [ -n "$ORIG_VT" ] && chvt "$ORIG_VT"
  exit 0
}

case "$CHOICE" in
  1)
    systemctl poweroff
    ;;
  2)
    systemctl reboot
    ;;
  *)
    # Cancel or unknown - return to original VT
    [ -n "$ORIG_VT" ] && chvt "$ORIG_VT"
    exit 0
    ;;
esac
