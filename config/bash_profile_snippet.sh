# Auto-run kid menu only on local interactive TTY (not SSH)
if [[ -t 0 && -z "${SSH_CONNECTION:-}" ]]; then
  # Enable console blanking after 10 minutes of inactivity
  setterm --blank 10 2>/dev/null || true

  # If the menu exits, we drop back to a shell.
  # If you prefer to log out instead, replace the last line with: exec logout
  "$HOME/bin/menu.sh"
fi
