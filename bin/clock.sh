#!/usr/bin/env bash
set -euo pipefail

# Launch analog clock (with second hand)
xclock -analog -update 1 -geometry 300x300+50+50 &
ANALOG_PID=$!

# Launch digital clock in terminal (nicer display)
# -C sets color (cyan), -s shows seconds, -c centers the clock
xterm -geometry 50x10+400+50 -e tty-clock -sC 6 -c &
DIGITAL_PID=$!

# Wait for either to exit, then kill the other
wait -n $ANALOG_PID $DIGITAL_PID
kill $ANALOG_PID $DIGITAL_PID 2>/dev/null || true
