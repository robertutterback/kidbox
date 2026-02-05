# Auto-run kid menu only on local interactive TTY (not SSH)
if [[ -t 0 && -z "${SSH_CONNECTION:-}" ]]; then

  # Set large console font for children before showing menu
  # Using Terminus 32x16 (32 px tall, 16 px wide) for maximum readability
  if command -v setfont >/dev/null 2>&1; then
    (setfont ter-v32n || setfont ter-132n || setfont /usr/share/consolefonts/Lat15-Terminus32x16.psf.gz) >/dev/null 2>&1 || true
  fi

  # Enable console blanking after 10 minutes of inactivity
  setterm --blank 10 2>/dev/null || true

  # If the menu exits, we drop back to a shell.
  # If you prefer to log out instead, replace the last line with: exec logout
  "$HOME/bin/menu.sh"
fi
