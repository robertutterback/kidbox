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
# The menu is displayed on VT1 (the console) to ensure it's visible
# whether the user is in the console menu or in an X session.

# Remember which VT we're on so we can return on Cancel
ORIG_VT=$(cat /sys/class/tty/tty0/active 2>/dev/null | grep -o '[0-9]*$') || ORIG_VT=""

# Switch to VT1 to ensure menu is visible
chvt 1

# Show power menu on tty1
CHOICE=$(
  whiptail --title "Power Button" \
    --menu "What would you like to do?" 12 50 3 \
      1 "Shutdown" \
      2 "Reboot" \
      3 "Cancel" \
    3>&1 1>&2 2>&3 </dev/tty1 >/dev/tty1
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
