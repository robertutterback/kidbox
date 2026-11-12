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
# Settings come from ~/kidbox/presets/dosbox.conf, and then, if it exists,
# from dosbox-<folder>.conf next to it, which overrides them for that one
# program (e.g. dosbox-oregon-trail.conf runs Oregon Trail in a window).
#
# Two helpers run alongside DOSBox:
# - kidbox-quit-watch.py makes Ctrl+Alt+Backspace work. DOSBox grabs the
#   keyboard, so xbindkeys, which handles it everywhere else, never sees it.
# - setup_window gives DOSBox the keyboard once its window is up (without it
#   the keyboard did nothing until the window was clicked) and centres the
#   window if it is smaller than the screen.
#
# What setup_window sees and does is written to ~/.kidbox-state/dos.log,
# replaced each time a program starts.

if [[ $# -lt 2 ]]; then
  echo "usage: dos.sh <folder> <DOS command...>" >&2
  exit 2
fi

dir="$1"
shift

PRESETS="$HOME/kidbox/presets"
confs=( -conf "$PRESETS/dosbox.conf" )
override="$PRESETS/dosbox-$(basename "$dir").conf"
[[ -f "$override" ]] && confs+=( -conf "$override" )

# Our own window class, so the window can be found without guessing what
# SDL calls it.
WM_CLASS="kidbox-dos"

LOG="$HOME/.kidbox-state/dos.log"
mkdir -p "$(dirname "$LOG")"
: >"$LOG"

log() {
  printf '%s %s\n' "$(date +%T)" "$*" >>"$LOG"
}

# Prints "x y width height" for a window, or "? ? ? ?".
window_geometry() {
  local WINDOW X Y WIDTH HEIGHT SCREEN
  eval "$(xdotool getwindowgeometry --shell "$1" 2>>"$LOG")"
  echo "${X:-?} ${Y:-?} ${WIDTH:-?} ${HEIGHT:-?}"
}

# Moves a window smaller than the screen to the middle of it. matchbox
# ignores a window's own request to be centred (SDL_VIDEO_CENTERED), so move
# it from outside: first the window itself, and if matchbox ignores that
# too, the frame matchbox has wrapped around it.
center_window() {
  local win="$1" sw sh x y w h tx ty frame
  read -r sw sh < <(xdotool getdisplaygeometry 2>>"$LOG")
  read -r x y w h < <(window_geometry "$win")
  log "screen ${sw}x${sh}; window $win at $x,$y, ${w}x${h}"
  [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] || return
  (( w < sw || h < sh )) || return
  tx=$(( (sw - w) / 2 ))
  ty=$(( (sh - h) / 2 ))

  xdotool windowmove "$win" "$tx" "$ty" 2>>"$LOG"
  sleep 0.2
  read -r x y w h < <(window_geometry "$win")
  log "moved the window to $tx,$ty; it is at $x,$y"
  [[ "$x,$y" == "$tx,$ty" ]] && return

  frame="$(xwininfo -tree -id "$win" 2>>"$LOG" \
             | awk '/Parent window id:/ && !/root window/ { print $4 }')"
  log "frame: ${frame:-none}"
  [[ -n "$frame" ]] || return
  xdotool windowmove "$frame" "$tx" "$ty" 2>>"$LOG"
  sleep 0.2
  read -r x y w h < <(window_geometry "$win")
  log "moved the frame to $tx,$ty; the window is at $x,$y"
}

setup_window() {
  # This runs in the background, where one failed step must not skip the
  # rest (set -e would end it at the first failure).
  set +e
  local win
  win="$(timeout 15 xdotool search --sync --onlyvisible --class "$WM_CLASS" \
           2>>"$LOG" | head -n1)"
  if [[ -z "$win" ]]; then
    log "no DOSBox window found"
    return
  fi
  log "found window $win"
  # In a limited session the time-left bar (kidbox-limit-bar.py, started by
  # .xinitrc) appears a second or so after DOSBox and takes the focus with
  # it, so focusing DOSBox before then does not stick. Wait for the bar.
  if [[ -n "${KID_LIMIT_BUDGET:-}" ]]; then
    timeout 15 xdotool search --sync --onlyvisible --name '^kidbox-limit-bar$' \
      >/dev/null 2>>"$LOG" || log "no time bar appeared"
  fi
  # SDL may still be setting the window up when it first appears, and the
  # bar may still be settling.
  sleep 0.5
  center_window "$win"
  xdotool windowfocus "$win" 2>>"$LOG"
  log "focused $win; focus is now on $(xdotool getwindowfocus 2>>"$LOG")"
}

# SDL_VIDEO_X11_DGAMOUSE=0: in fullscreen, SDL 1.2 reads the mouse through
# the XFree86-DGA extension, which on the Pi made Storybook Weaver's pointer
# drift and jump on its own. Plain X mouse events behave.
SDL_VIDEO_X11_DGAMOUSE=0 SDL_VIDEO_X11_WMCLASS="$WM_CLASS" dosbox \
  "${confs[@]}" \
  -c "mount c \"$dir\"" \
  -c "c:" \
  -c "$*" \
  -c "exit" &
dosbox_pid=$!

"$HOME/bin/kidbox-quit-watch.py" "$dosbox_pid" &
watch_pid=$!

setup_window &

# DOSBox ends either on its own or because the watcher ended it; either way
# the session is over.
wait "$dosbox_pid" || true
kill "$watch_pid" 2>/dev/null || true
