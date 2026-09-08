#!/usr/bin/env bash
set -euo pipefail

# Nudge the volume from a key binding (see config/xbindkeysrc).
#
# Usage: kidbox-volume.sh up|down|mute
#
# -M makes the percentage follow loudness as the ear hears it. Without it
# amixer scales the raw hardware value, and on the Pi's headphone output the
# raw range is so wide that a "60%" setting is nearly silent. That is how
# an earlier attempt to soften websites ended up inaudible.
#
# Master and PCM are both nudged because which one exists depends on the
# output (HDMI vs headphones); the missing one fails quietly.

STEP=5%

case "${1:?usage: kidbox-volume.sh up|down|mute}" in
  up)   change="${STEP}+ unmute" ;;
  down) change="${STEP}-" ;;
  mute) change="toggle" ;;
  *)    echo "usage: kidbox-volume.sh up|down|mute" >&2; exit 2 ;;
esac

# shellcheck disable=SC2086
amixer -q -M sset Master $change 2>/dev/null || true
# shellcheck disable=SC2086
amixer -q -M sset PCM $change 2>/dev/null || true
