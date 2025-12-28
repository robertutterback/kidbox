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
) || exit 0  # User pressed Esc or Cancel

case "$CHOICE" in
  1)
    # Shutdown
    systemctl poweroff
    ;;
  2)
    # Reboot
    systemctl reboot
    ;;
  3)
    # Cancel - just exit
    exit 0
    ;;
  *)
    # Unknown choice - just exit
    exit 0
    ;;
esac
