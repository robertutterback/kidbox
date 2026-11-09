#!/usr/bin/env bash
set -euo pipefail

# Kid kiosk behavior:
# - no Exit option
# - Esc/cancel returns to menu
# - Ctrl+C does nothing
#
# Use --dev flag for local testing (adds Exit option, allows Ctrl+C)

VERSION="1.5"
DEV_MODE=false
if [[ "${1:-}" == "--dev" ]]; then
  DEV_MODE=true
fi

if [[ "$DEV_MODE" == false ]]; then
  trap '' INT
fi

KIDBOX_DIR="$HOME/kidbox"
LOG_DIR="$HOME/.kidbox-logs"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/$(date +%Y-%m-%d).log"

SALLY_FILE="$KIDBOX_DIR/typing/sally.txt"
PENNY_FILE="$KIDBOX_DIR/typing/penny.txt"
LOGO_WELCOME="$KIDBOX_DIR/presets/welcome.lg"
# Each starts in its own folder rather than the home directory. That is what
# decides where BASIC saves. It does not decide it for Logo: UCBLogo's window
# moves to the home directory once it has loaded welcome.lg, so welcome.lg
# sets the save folder itself with SETPREFIX.
LOGO_DIR="$KIDBOX_DIR/logo"
BASIC_DIR="$KIDBOX_DIR/basic"
CLOCK_SCRIPT="$HOME/bin/clock.sh"
TIMER_SCRIPT="$HOME/bin/timer.sh"
STOPWATCH_SCRIPT="$HOME/bin/stopwatch.sh"
DICTIONARY_SCRIPT="$HOME/bin/dictionary.sh"
BOOK_PDF="$KIDBOX_DIR/kidbook.pdf"
SITE_SCRIPT="$HOME/bin/site.sh"
SITES_CONF="${KIDBOX_SITES_CONF:-/etc/kidbox/sites.conf}"

# -----------------------------------------------------------------------------
# Daily screen-time limits
#
# Two separate budgets ("pools"), each with its own minutes and state file, so
# time spent in one never uses up the other:
#   ixl    the items named in IXL_NAMES (menu names, exactly as they appear in
#          MENU_ITEMS below or in sites.conf)
#   games  every game in the Games submenu, except those named in
#          GAMES_EXEMPT. A new game is limited unless it is listed there.
#
# The menu refuses to start a limited item once its pool is spent, and
# kidbox-limit-bar.py -- started from .xinitrc when it sees KID_LIMIT_BUDGET --
# shows the countdown along the bottom of the screen and ends the session at
# zero. The bar is the only thing that writes a pool's state file, every few
# seconds, so a reboot loses at most that much.
#
# A state file holds "YYYY-MM-DD seconds-used". A file from any other day
# counts as zero, which is the whole daily reset; a session that runs past
# midnight is charged to the day it started.
# -----------------------------------------------------------------------------
declare -A POOL_WEEKDAY_MIN=( [ixl]=20 [games]=30 )
declare -A POOL_WEEKEND_MIN=( [ixl]=60 [games]=60 )
declare -A POOL_STATE=(
  [ixl]="$HOME/.kidbox-state/screen-time"
  [games]="$HOME/.kidbox-state/screen-time-games"
)
IXL_NAMES=(
  "IXL (School Practice)"
)
GAMES_EXEMPT=(
  "Adventures in Math"
)

# Usage: limit_budget_secs <pool>
limit_budget_secs() {
  if (( $(date +%u) >= 6 )); then
    echo $(( POOL_WEEKEND_MIN[$1] * 60 ))
  else
    echo $(( POOL_WEEKDAY_MIN[$1] * 60 ))
  fi
}

# Usage: limit_used_secs <pool>
limit_used_secs() {
  local state="${POOL_STATE[$1]}" day used
  # read fails at EOF on a line with no newline, but still fills the vars.
  if [[ -r "$state" ]] && { read -r day used _ < "$state" || true; } \
      && [[ "${day:-}" == "$(date +%F)" && "${used:-}" =~ ^[0-9]+$ ]]; then
    echo "$used"
  else
    echo 0
  fi
}

# Minutes left in a pool today, rounded up; 0 once it is spent.
# Usage: limit_left_min <pool>
limit_left_min() {
  local left=$(( $(limit_budget_secs "$1") - $(limit_used_secs "$1") ))
  (( left > 0 )) || left=0
  echo $(( (left + 59) / 60 ))
}

# What a limited item's menu label ends with, so running out is never a
# surprise.
# Usage: limit_label <pool>
limit_label() {
  local left
  left=$(limit_left_min "$1")
  if (( left > 0 )); then
    echo "  ($left min left today)"
  else
    echo "  (all done for today)"
  fi
}

# Function to run X programs with logging
# Usage: run_x <program> [args...]
run_x() {
  if [[ $# -lt 1 ]]; then
    echo "ERROR: run_x requires at least one argument" >&2
    return 2
  fi

  local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$timestamp] Starting: $*" >> "$LOGFILE"

  # Reset the volume on every launch so the timer alarm is always loud.
  # Inside an app the volume keys (kidbox-volume.sh) can turn it down; that
  # lasts until the next launch.
  amixer -q sset Master 100% unmute 2>/dev/null || true
  amixer -q sset PCM 100% unmute 2>/dev/null || true

  export KID_APP="$1"
  shift || true
  export KID_ARGS="${*:-}"

  # Start X server and capture output to log
  xinit -- :1 -br -nolisten tcp "vt${XDG_VTNR:-1}" >> "$LOGFILE" 2>&1

  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$timestamp] Finished: $KID_APP" >> "$LOGFILE"
}

# Start a program, charging it to a time pool unless the pool is empty.
# Usage: launch_in <pool-or-empty> <program> [args...]
launch_in() {
  local pool="$1"
  shift
  if [[ -z "$pool" ]]; then
    run_x "$@"
    return
  fi

  local budget used
  budget=$(limit_budget_secs "$pool")
  used=$(limit_used_secs "$pool")
  if (( used >= budget )); then
    whiptail --title "$MENU_TITLE" --msgbox \
      $'All done with that for today!\n\nIt will be back tomorrow.' 10 50
    return
  fi

  # .xinitrc starts the countdown bar when it sees these. Set for this one
  # call only.
  KID_LIMIT_BUDGET="$budget" KID_LIMIT_USED="$used" \
    KID_LIMIT_STATE="${POOL_STATE[$pool]}" run_x "$@"
}

# Start the chosen main-menu item, enforcing its pool if it has one. Reads the
# tag from $CHOICE so the case below reads the same for every item.
# Usage: launch <program> [args...]
launch() {
  launch_in "${LIMITED_TAG[$CHOICE]:-}" "$@"
}

# -----------------------------------------------------------------------------
# Games (DOS programs, run in DOSBox by dos.sh)
#
# One line per game: menu name | folder under $DOS_DIR | DOS command to run.
# A game appears only once install.sh has put its folder in place (the files
# come from content/dos/<folder>/, which is kept out of git), and the Games
# item appears only once there is at least one game.
# -----------------------------------------------------------------------------
DOS_SCRIPT="$HOME/bin/dos.sh"
DOS_DIR="$KIDBOX_DIR/dos"
GAMES=(
  # VGA is named because the game's own README says its graphics detection
  # can fail.
  "The Oregon Trail|oregon-trail|OREGON VGA"
  # The game ships its own BASICA.EXE: COMPAQ BASIC 1.13, which, unlike
  # IBM's BASICA, does not need BASIC in ROM, so it runs in DOSBox.
  "Adventures in Math|adventures-in-math|BASICA CASTLE"
)

# The pool a game is charged to: empty if exempt, "games" otherwise.
# Usage: game_pool <menu-name>
game_pool() {
  local name
  for name in "${GAMES_EXEMPT[@]}"; do
    [[ "$name" == "$1" ]] && return 0
  done
  echo games
}

# Installed games, one "name|folder|command" line each.
installed_games() {
  local line name dir cmd
  for line in "${GAMES[@]}"; do
    IFS='|' read -r name dir cmd <<< "$line"
    [[ -d "$DOS_DIR/$dir" ]] && printf '%s\n' "$line"
  done
  return 0
}

games_menu() {
  local -a games items
  local i choice name dir cmd pool label
  mapfile -t games < <(installed_games)

  while true; do
    items=()
    for i in "${!games[@]}"; do
      IFS='|' read -r name dir cmd <<< "${games[i]}"
      label="$name"
      pool=$(game_pool "$name")
      [[ -n "$pool" ]] && label+=$(limit_label "$pool")
      items+=( "$(( i + 1 ))" "$label" )
    done
    items+=( "0" "Back to the main menu" )

    choice=$(
      whiptail --title "$MENU_TITLE" --nocancel \
        --menu "Choose a game" "$TERM_LINES" "$TERM_COLS" "$MENU_ROWS" \
          "${items[@]}" \
        3>&1 1>&2 2>&3
    ) || return 0
    [[ "$choice" == 0 ]] && return 0

    IFS='|' read -r name dir cmd <<< "${games[choice - 1]}"
    # cmd is left unquoted on purpose: "BASICA CASTLE" goes in as two words,
    # and dos.sh joins them back up.
    # shellcheck disable=SC2086
    launch_in "$(game_pool "$name")" "$DOS_SCRIPT" "$DOS_DIR/$dir" $cmd
  done
}

MENU_TITLE="Girls' Computer (v$VERSION)"
MENU_ITEMS=(
  1 "Type Letters (Sally)"
  2 "Type Letters (Penny)"
  3 "Draw Pictures"
  4 "Draw Pictures with Logo Turtle"
  5 "Write BASIC Programs"
  6 "Clock"
  7 "Timer"
  8 "Stopwatch"
  9 "Read the Book"
  10 "Look Up a Word"
)

# Storybook Weaver is a DOS program like the games, but not a game: it goes
# on the main menu, with no time limit. Like the games, it shows only once
# install.sh has put its folder in place.
STORYBOOK_DIR="$DOS_DIR/storybook-weaver"
STORYBOOK_TAG=""
site_tag=11
if [[ -d "$STORYBOOK_DIR" ]]; then
  STORYBOOK_TAG=$site_tag
  MENU_ITEMS+=( "$STORYBOOK_TAG" "Storybook Weaver" )
  site_tag=$(( site_tag + 1 ))
fi

# Games, if any are installed, take the next number.
GAMES_TAG=""
if [[ -n "$(installed_games)" ]]; then
  GAMES_TAG=$site_tag
  MENU_ITEMS+=( "$GAMES_TAG" "Games" )
  site_tag=$(( site_tag + 1 ))
fi

# Website items come from $SITES_CONF, read fresh every time the menu is drawn,
# so the menu shows a new site as soon as install.sh has written the file. The
# browser allowlist is generated from the same file by kidbox-gen-policy.py.
#
# Numbering runs straight on from the activities above (and Storybook Weaver
# and Games, if they are there): websites take the next numbers, and Shutdown takes whatever number
# comes after them. No gaps, no reserved numbers.
declare -A SITE_URL=()
declare -A SITE_SLUG=()

if [[ -r "$SITES_CONF" ]]; then
  while IFS='|' read -r kind name url _rest; do
    [[ "${kind// /}" == "SITE" ]] || continue
    [[ -n "${name:-}" && -n "${url:-}" ]] || continue

    # Slug names the throwaway browser profile directory.
    slug="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' \
              | tr -cs '[:alnum:]' '-' | sed 's/^-//; s/-$//')"

    MENU_ITEMS+=( "$site_tag" "$name" )
    SITE_URL[$site_tag]="$url"
    SITE_SLUG[$site_tag]="$slug"
    site_tag=$(( site_tag + 1 ))
  done < "$SITES_CONF"
fi

SHUTDOWN_TAG=$site_tag
MENU_ITEMS+=( "$SHUTDOWN_TAG" "Shutdown Computer" )

# Pool of each limited main-menu item, looked up by name so a site can be
# limited without knowing which number it landed on. Games are not in here:
# the Games submenu charges each game itself.
declare -A LIMITED_TAG=()
for (( i = 0; i < ${#MENU_ITEMS[@]}; i += 2 )); do
  for name in "${IXL_NAMES[@]}"; do
    if [[ "${MENU_ITEMS[i+1]}" == "$name" ]]; then
      LIMITED_TAG[${MENU_ITEMS[i]}]=ixl
    fi
  done
done

if [[ "$DEV_MODE" == true ]]; then
  MENU_TITLE+=" [dev mode]"
fi

# Blue theme for whiptail (default window color is gray, which looks bad
# when the dialog fills the entire terminal).
# Button colors match the background to hide the Ok button; whiptail has
# --nocancel to remove Cancel but no --nook equivalent, so this is the
# only way to hide it.
export NEWT_COLORS='
root=white,blue
window=white,blue
border=white,blue
shadow=white,black
title=white,blue
textbox=white,blue
listbox=white,blue
actlistbox=black,lightgray
button=white,blue
actbutton=white,blue
helpline=white,blue
roottext=white,blue
entry=black,lightgray
label=white,blue
'

while true; do

  # Size the menu to fill the terminal
  TERM_LINES="${LINES:-$(tput lines 2>/dev/null || echo 24)}"
  TERM_COLS="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
  MENU_ROWS=$(( TERM_LINES - 8 ))

  # Limited items say what is left today, so running out is never a surprise.
  ITEMS=()
  for (( i = 0; i < ${#MENU_ITEMS[@]}; i += 2 )); do
    tag="${MENU_ITEMS[i]}"
    name="${MENU_ITEMS[i+1]}"
    if [[ -n "${LIMITED_TAG[$tag]:-}" ]]; then
      name+=$(limit_label "${LIMITED_TAG[$tag]}")
    elif [[ "$tag" == "$GAMES_TAG" ]]; then
      # Exempt games are still playable once game time is spent, so this
      # does not say "all done".
      left=$(limit_left_min games)
      if (( left > 0 )); then
        name+="  ($left min of game time left)"
      else
        name+="  (game time used up)"
      fi
    fi
    ITEMS+=( "$tag" "$name" )
  done

  CHOICE=$(
    whiptail --title "$MENU_TITLE" --nocancel \
      --menu "Choose something to do" "$TERM_LINES" "$TERM_COLS" "$MENU_ROWS" \
        "${ITEMS[@]}" \
      3>&1 1>&2 2>&3
  ) || {
    # Esc / Cancel: exit in dev mode, re-show menu otherwise
    if [[ "$DEV_MODE" == true ]]; then
      exit 0
    fi
    continue
  }

  case "$CHOICE" in
    1) launch leafpad "$SALLY_FILE" ;;
    2) launch leafpad "$PENNY_FILE" ;;
    3) launch tuxpaint ;;
    4) (cd "$LOGO_DIR" && launch ucblogo "$LOGO_WELCOME") ;;
    5) (cd "$BASIC_DIR" && launch pcbasic) ;;
    6) launch "$CLOCK_SCRIPT" ;;
    7) launch "$TIMER_SCRIPT" ;;
    8) launch "$STOPWATCH_SCRIPT" ;;
    9) launch chromium-browser --kiosk --app="file://$BOOK_PDF" ;;
    10) launch "$DICTIONARY_SCRIPT" ;;
    "$SHUTDOWN_TAG") sudo shutdown -h now ;;
    0) exit 0 ;;
    *)
      # Storybook, Games and website tags are assigned above, so look the
      # choice up instead of hard-coding a case for each.
      if [[ "$CHOICE" == "$STORYBOOK_TAG" ]]; then
        # No "VGA" argument, though the README suggests it when detection
        # fails: with it, SBW asked for graphics and sound settings on every
        # launch instead of using SBW.CFG.
        launch "$DOS_SCRIPT" "$STORYBOOK_DIR" SBW
      elif [[ "$CHOICE" == "$GAMES_TAG" ]]; then
        games_menu
      elif [[ -n "${SITE_URL[$CHOICE]:-}" ]]; then
        launch "$SITE_SCRIPT" "${SITE_URL[$CHOICE]}" "${SITE_SLUG[$CHOICE]}"
      fi
      ;;
  esac
done
