#!/usr/bin/env bash
set -euo pipefail

# Show the dictionary in a large fullscreen xterm.
exec xterm -maximized -fa 'Monospace' -fs 18 -e "$HOME/bin/dictionary-lookup.sh"
