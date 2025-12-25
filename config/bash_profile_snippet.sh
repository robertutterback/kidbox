# Auto-run kid menu only on local interactive TTY (not SSH)
if [[ -t 0 && -z "${SSH_CONNECTION:-}" ]]; then
  # Set large console font for children before showing menu
  # Using Terminus 32x16 for maximum readability
  if command -v setfont >/dev/null 2>&1; then
    setfont /usr/share/consolefonts/Lat15-Terminus32x16.psf.gz 2>/dev/null || \
    setfont ter-132n 2>/dev/null || \
    setfont ter-v32n 2>/dev/null || true
  fi

  # If the menu exits, we drop back to a shell.
  # If you prefer to log out instead, replace the last line with: exec logout
  "$HOME/bin/menu.sh"
fi
