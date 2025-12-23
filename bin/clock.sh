#!/usr/bin/env bash
set -euo pipefail

CLOCK_HTML="$HOME/kidbox/clock.html"

exec chromium-browser --kiosk --app="file://$CLOCK_HTML"
