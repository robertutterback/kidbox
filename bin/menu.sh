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
# Logo and BASIC save into whatever directory they were started from, so
# each starts in its own folder rather than the home directory.
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
# Daily screen-time limit
#
# Minutes per day, shared by every item named in LIMITED_NAMES (menu names,
# exactly as they appear in MENU_ITEMS below or in sites.conf). The menu
# refuses to start a limited item once the day's budget is spent, and
# kidbox-limit-bar.py -- started from .xinitrc when it sees KID_LIMIT_BUDGET --
# shows the countdown along the bottom of the screen and ends the session at
# zero. The bar is the only thing that writes the state file, every few
# seconds, so a reboot loses at most that much.
#
# The state file holds "YYYY-MM-DD seconds-used". A file from any other day
# counts as zero, which is the whole daily reset; a session that runs past
# midnight is charged to the day it started.
# -----------------------------------------------------------------------------
LIMIT_WEEKDAY_MIN=20
LIMIT_WEEKEND_MIN=60
LIMITED_NAMES=(
  "IXL (School Practice)"
)
LIMIT_STATE="$HOME/.kidbox-state/screen-time"

limit_budget_secs() {
  if (( $(date +%u) >= 6 )); then
    echo $(( LIMIT_WEEKEND_MIN * 60 ))
  else
    echo $(( LIMIT_WEEKDAY_MIN * 60 ))
  fi
}

limit_used_secs() {
  local day used
  # read fails at EOF on a line with no newline, but still fills the vars.
  if [[ -r "$LIMIT_STATE" ]] && { read -r day used _ < "$LIMIT_STATE" || true; } \
      && [[ "${day:-}" == "$(date +%F)" && "${used:-}" =~ ^[0-9]+$ ]]; then
    echo "$used"
  else
    echo 0
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

# Start the chosen menu item, enforcing the daily limit if it is a limited
# one. Reads the tag from $CHOICE so the case below reads the same for every
# item.
# Usage: launch <program> [args...]
launch() {
  if [[ -z "${LIMITED_TAG[$CHOICE]:-}" ]]; then
    run_x "$@"
    return
  fi

  local budget used
  budget=$(limit_budget_secs)
  used=$(limit_used_secs)
  if (( used >= budget )); then
    whiptail --title "$MENU_TITLE" --msgbox \
      $'All done with that for today!\n\nIt will be back tomorrow.' 10 50
    return
  fi

  # .xinitrc starts the countdown bar when it sees these. Set for this one
  # call only.
  KID_LIMIT_BUDGET="$budget" KID_LIMIT_USED="$used" run_x "$@"
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

# Website items come from $SITES_CONF, read fresh every time the menu is drawn,
# so the menu shows a new site as soon as install.sh has written the file. The
# browser allowlist is generated from the same file by kidbox-gen-policy.py.
#
# Numbering runs straight on from the activities above: websites take 11, 12,
# 13... and Shutdown takes whatever number comes next. No gaps, no reserved
# numbers.
declare -A SITE_URL=()
declare -A SITE_SLUG=()
site_tag=11

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

# Tags of the limited items, looked up by name so a site can be limited
# without knowing which number it landed on.
declare -A LIMITED_TAG=()
for (( i = 0; i < ${#MENU_ITEMS[@]}; i += 2 )); do
  for name in "${LIMITED_NAMES[@]}"; do
    if [[ "${MENU_ITEMS[i+1]}" == "$name" ]]; then
      LIMITED_TAG[${MENU_ITEMS[i]}]=1
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
  budget=$(limit_budget_secs)
  used=$(limit_used_secs)
  ITEMS=()
  for (( i = 0; i < ${#MENU_ITEMS[@]}; i += 2 )); do
    tag="${MENU_ITEMS[i]}"
    name="${MENU_ITEMS[i+1]}"
    if [[ -n "${LIMITED_TAG[$tag]:-}" ]]; then
      if (( used < budget )); then
        name+="  ($(( (budget - used + 59) / 60 )) min left today)"
      else
        name+="  (all done for today)"
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
      # Website tags are assigned above, so look the choice up instead of
      # hard-coding a case per site.
      if [[ -n "${SITE_URL[$CHOICE]:-}" ]]; then
        launch "$SITE_SCRIPT" "${SITE_URL[$CHOICE]}" "${SITE_SLUG[$CHOICE]}"
      fi
      ;;
  esac
done
