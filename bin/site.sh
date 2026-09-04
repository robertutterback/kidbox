#!/usr/bin/env bash
set -euo pipefail

# Open a website with no address bar.
#
# Usage: site.sh <url> [slug]
#
# Launched by menu.sh through run_x, so this already runs inside its own X
# session; when Chromium exits, the session ends and the kid is back at the
# menu. What keeps the browsing inside the allowlist is the Chromium managed
# policy (see kidbox-gen-policy.py), not anything in this script -- kiosk mode
# only removes the address bar, it is not a boundary.

URL="${1:?usage: site.sh <url> [slug]}"
SLUG="${2:-web}"

# Stateless on purpose: wipe the profile every launch. No cookies or cache
# survive between sessions, so there are no logins to worry about and nothing
# grows on the SD card, which is the part of a Pi that dies from writes.
PROFILE="$HOME/.kidbox-browser/$SLUG"
rm -rf "$PROFILE"
mkdir -p "$PROFILE"

# run_x sets the volume to 100% before every launch so the timer alarm is
# loud. Websites autoplay, and 100% is startling; turn it down for ourselves
# only, since the next launch resets it.
WEB_VOLUME="${KIDBOX_WEB_VOLUME:-60%}"
amixer -q sset Master "$WEB_VOLUME" 2>/dev/null || true
amixer -q sset PCM "$WEB_VOLUME" 2>/dev/null || true

# Esc = go back. Kiosk + app mode has no back button, so a kid who clicks a
# link to a blocked domain would otherwise be stranded on the block page with
# no way to the page they came from. Alt+Left works natively; this makes Esc
# an alias, matching what Esc does in the menu. Only bound while a website is
# open, so it never steals Esc from Logo or BASIC.
if [[ -f "$HOME/.xbindkeysrc-web" ]] && command -v xdotool >/dev/null 2>&1; then
  xbindkeys -f "$HOME/.xbindkeysrc-web" &
fi

exec chromium-browser \
  --kiosk \
  --app="$URL" \
  --user-data-dir="$PROFILE" \
  --no-first-run \
  --no-default-browser-check \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-features=TranslateUI \
  --password-store=basic
