#!/usr/bin/env bash
set -euo pipefail

# Run one DOS program in DOSBox and quit DOSBox when it ends, which ends the
# X session and drops the kid back at the menu.
#
# Usage: dos.sh <folder> <DOS command...>
#   e.g. dos.sh ~/kidbox/dos/oregon-trail OREGON VGA
#
# The folder is mounted as drive C:, and it is the kid's own copy, so games
# that save (high scores, stories) can write to it. The command may arrive as
# several words -- .xinitrc splits KID_ARGS on spaces -- so they are joined
# back into one DOS command line.
#
# Two helpers run alongside DOSBox:
# - kidbox-quit-watch.py makes Ctrl+Alt+Backspace work. DOSBox grabs the
#   keyboard, so xbindkeys, which handles it everywhere else, never sees it.
# - focus_dosbox gives DOSBox the keyboard once its window is up. Without it
#   the keyboard did nothing until the window was clicked.

if [[ $# -lt 2 ]]; then
  echo "usage: dos.sh <folder> <DOS command...>" >&2
  exit 2
fi

dir="$1"
shift

# Our own window class, so the window can be found without guessing what
# SDL calls it.
WM_CLASS="kidbox-dos"

focus_dosbox() {
  local win
  win="$(timeout 15 xdotool search --sync --onlyvisible --class "$WM_CLASS" \
           2>/dev/null | head -n1)" || return 0
  [[ -n "$win" ]] || return 0
  # In a limited session the time-left bar (kidbox-limit-bar.py, started by
  # .xinitrc) appears a second or so after DOSBox and takes the focus with
  # it, so focusing DOSBox before then does not stick. Wait for the bar.
  if [[ -n "${KID_LIMIT_BUDGET:-}" ]]; then
    timeout 15 xdotool search --sync --onlyvisible --name '^kidbox-limit-bar$' \
      >/dev/null 2>&1 || true
  fi
  # SDL may still be setting the window up when it first appears, and the
  # bar may still be settling.
  sleep 0.5
  xdotool windowfocus "$win" 2>/dev/null || true
}

# SDL_VIDEO_X11_DGAMOUSE=0: in fullscreen, SDL 1.2 reads the mouse through
# the XFree86-DGA extension, which on the Pi made Storybook Weaver's pointer
# drift and jump on its own. Plain X mouse events behave.
SDL_VIDEO_X11_DGAMOUSE=0 SDL_VIDEO_X11_WMCLASS="$WM_CLASS" dosbox \
  -conf "$HOME/kidbox/presets/dosbox.conf" \
  -c "mount c \"$dir\"" \
  -c "c:" \
  -c "$*" \
  -c "exit" &
dosbox_pid=$!

"$HOME/bin/kidbox-quit-watch.py" "$dosbox_pid" &
watch_pid=$!

focus_dosbox &

# DOSBox ends either on its own or because the watcher ended it; either way
# the session is over.
wait "$dosbox_pid" || true
kill "$watch_pid" 2>/dev/null || true
