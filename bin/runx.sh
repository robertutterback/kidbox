#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: run-x.sh <program> [args...]"
  exit 2
fi

export KID_APP="$1"
shift || true

# Optional args string used by .xinitrc
# We keep it simple: space-joined args. This is fine for typical paths without weird quoting.
export KID_ARGS="${*:-}"

# Start X server :1 on the current VT. No desktop environment.
exec xinit -- :1 -br -nolisten tcp "vt${XDG_VTNR:-1}"
