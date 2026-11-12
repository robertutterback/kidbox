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
#   window of a program that runs in one.
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
WIN_SIZE=""  # "width height" if the override runs the program in a window
if [[ -f "$override" ]]; then
  confs+=( -conf "$override" )
  WIN_SIZE="$(sed -n 's/^windowresolution=\([0-9]\+\)x\([0-9]\+\)$/\1 \2/p' \
                "$override" | tail -n1)"
fi

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

# Puts a windowed program (one whose override sets windowresolution) in the
# middle of the screen at that size. matchbox stretches every app window to
# fill the screen -- the log showed DOSBox's 1440x900 window at 1920x1048 --
# and DOSBox then draws in the top-left corner of it. So take the window
# away from matchbox: an override-redirect window is one the window manager
# leaves alone, and the setting takes effect when the window is next shown,
# hence the unmap and map.
center_window() {
  local win="$1" sw sh x y w h tw th tx ty
  read -r sw sh < <(xdotool getdisplaygeometry 2>>"$LOG")
  read -r x y w h < <(window_geometry "$win")
  log "screen ${sw}x${sh}; window $win at $x,$y, ${w}x${h}"
  [[ -n "$WIN_SIZE" ]] || return
  read -r tw th <<< "$WIN_SIZE"
  tx=$(( (sw - tw) / 2 ))
  ty=$(( (sh - th) / 2 ))

  xdotool windowunmap --sync "$win" 2>>"$LOG"
  xdotool set_window --overrideredirect 1 "$win" 2>>"$LOG"
  xdotool windowmap --sync "$win" 2>>"$LOG"
  xdotool windowsize "$win" "$tw" "$th" 2>>"$LOG"
  xdotool windowmove "$win" "$tx" "$ty" 2>>"$LOG"
  sleep 0.2
  read -r x y w h < <(window_geometry "$win")
  log "wanted ${tw}x${th} at $tx,$ty; window is ${w}x${h} at $x,$y"
}

# Centres and focuses each DOSBox window as it appears, for as long as
# DOSBox runs. Windowed, DOSBox replaces its first window within a second
# of starting (the log showed the one first found gone by the time it was
# focused), and may replace it again when the game changes screen size, so
# acting once on the first window found is not enough.
# Usage: setup_window <dosbox-pid>
setup_window() {
  # This runs in the background, where one failed step must not skip the
  # rest (set -e would end it at the first failure).
  set +e
  local pid="$1" win last=""
  # In a limited session the time-left bar (kidbox-limit-bar.py, started by
  # .xinitrc) appears a second or so after DOSBox and takes the focus with
  # it, so focusing DOSBox before then does not stick. Wait for the bar.
  if [[ -n "${KID_LIMIT_BUDGET:-}" ]]; then
    timeout 15 xdotool search --sync --onlyvisible --name '^kidbox-limit-bar$' \
      >/dev/null 2>>"$LOG" || log "no time bar appeared"
  fi
  while kill -0 "$pid" 2>/dev/null; do
    win="$(xdotool search --onlyvisible --class "$WM_CLASS" 2>/dev/null \
             | tail -n1)"
    if [[ -n "$win" && "$win" != "$last" ]]; then
      # SDL may still be setting the window up, or about to replace it.
      sleep 0.5
      if xdotool getwindowname "$win" >/dev/null 2>&1; then
        log "found window $win"
        center_window "$win"
        xdotool windowfocus "$win" 2>>"$LOG"
        log "focused $win; focus is now on $(xdotool getwindowfocus 2>>"$LOG")"
        last="$win"
      else
        log "window $win went away before it could be set up"
      fi
    fi
    sleep 0.5
  done
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

setup_window "$dosbox_pid" &
setup_pid=$!

# DOSBox ends either on its own or because the watcher ended it; either way
# the session is over.
wait "$dosbox_pid" || true
kill "$watch_pid" "$setup_pid" 2>/dev/null || true
