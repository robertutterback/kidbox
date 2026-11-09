#!/usr/bin/env bash
set -euo pipefail

# Run one DOS program in DOSBox and quit DOSBox when it ends, which ends the
# X session and drops the kid back at the menu.
#
# Usage: dos.sh <folder> <DOS command...>
#   e.g. dos.sh ~/kidbox/dos/oregon-trail OREGON
#
# The folder is mounted as drive C:, and it is the kid's own copy, so games
# that save (high scores, stories) can write to it. The command may arrive as
# several words -- .xinitrc splits KID_ARGS on spaces -- so they are joined
# back into one DOS command line.

if [[ $# -lt 2 ]]; then
  echo "usage: dos.sh <folder> <DOS command...>" >&2
  exit 2
fi

dir="$1"
shift

exec dosbox -conf "$HOME/kidbox/presets/dosbox.conf" \
  -c "mount c \"$dir\"" \
  -c "c:" \
  -c "$*" \
  -c "exit"
