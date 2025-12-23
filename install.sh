#!/usr/bin/env bash
set -euo pipefail

# Initially created by ChatGPT with my guidance.

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root."
    exit 1
fi


# -------------------------------
# Config
# -------------------------------
KID_USER="${KID_USER:-girls}"

# Create kid user if missing
if ! id -u "$KID_USER" >/dev/null 2>&1; then
  echo "[kidbox] Creating user '$KID_USER'..."
  # No password (console autologin will be enabled separately via raspi-config)
  adduser --disabled-password --gecos "" "$KID_USER"
  
  # Useful groups for sound/video/input devices
  for g in audio video input plugdev render; do
    if getent group "$g" >/dev/null 2>&1; then
      usermod -aG "$g" "$KID_USER"
    fi
  done
fi

KID_HOME="$(getent passwd "$KID_USER" | cut -d: -f6)"
if [[ -z "${KID_HOME}" || ! -d "${KID_HOME}" ]]; then
  echo "ERROR: user '$KID_USER' not found or home directory missing."
  echo "Create the user first, or run with: sudo KID_USER=someuser ./install.sh"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIDBOX_DIR="${KID_HOME}/kidbox"
KID_BIN_DIR="${KID_HOME}/bin"

# -------------------------------
# Packages
# -------------------------------
APT_PACKAGES=(
  ucblogo
  python3-pcbasic
  tuxpaint
  leafpad
  xserver-xorg
  xinit
  matchbox-window-manager
  unclutter
  whiptail
  xbindkeys
  x11-apps
  tty-clock
  zenity
  xterm
  alsa-utils
  xpdf
)

echo "[kidbox] Installing packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y "${APT_PACKAGES[@]}"

# -------------------------------
# Directories
# -------------------------------
echo "[kidbox] Creating directories..."
install -d -m 0755 "$KID_BIN_DIR"
install -d -m 0755 "$KIDBOX_DIR"
install -d -m 0755 "$KIDBOX_DIR/typing" "$KIDBOX_DIR/basic" "$KIDBOX_DIR/logo"

# -------------------------------
# Install scripts
# -------------------------------
echo "[kidbox] Installing scripts..."
install -m 0755 "$REPO_ROOT/bin/menu.sh" "$KID_BIN_DIR/menu.sh"
install -m 0755 "$REPO_ROOT/bin/runx.sh" "$KID_BIN_DIR/runx.sh"
install -m 0755 "$REPO_ROOT/bin/clock.sh" "$KID_BIN_DIR/clock.sh"
install -m 0755 "$REPO_ROOT/bin/timer.sh" "$KID_BIN_DIR/timer.sh"

# -------------------------------
# Install .xinitrc
# -------------------------------
echo "[kidbox] Installing .xinitrc..."
install -m 0755 "$REPO_ROOT/config/xinitrc" "$KID_HOME/.xinitrc"

# -------------------------------
# Install .xbindkeysrc
# -------------------------------
echo "[kidbox] Installing .xbindkeysrc..."
install -m 0755 "$REPO_ROOT/config/xbindkeysrc" "$KID_HOME/.xbindkeysrc"

# -------------------------------
# Install content (do not clobber if already modified)
# - Use install -C to avoid overwriting identical files (GNU coreutils)
# - For typing files, we DO want them to persist; only create if missing.
# -------------------------------
echo "[kidbox] Installing content..."

# Typing files: create if missing (preserve kid-written stuff)
for f in "$REPO_ROOT/content/typing/"*.txt; do
  base="$(basename "$f")"
  dest="$KIDBOX_DIR/typing/$base"
  if [[ ! -f "$dest" ]]; then
    install -m 0644 "$f" "$dest"
  fi
done

# BASIC + Logo: copy "example" files; safe to overwrite (they're templates)
install -m 0644 "$REPO_ROOT/content/basic/HELLO.BAS" "$KIDBOX_DIR/basic/HELLO.BAS"
install -m 0644 "$REPO_ROOT/content/logo/welcome.lg" "$KIDBOX_DIR/logo/welcome.lg"

# Book PDF: copy if exists
if [[ -f "$REPO_ROOT/doc/kidbook.pdf" ]]; then
  install -m 0644 "$REPO_ROOT/doc/kidbook.pdf" "$KIDBOX_DIR/kidbook.pdf"
fi

# -------------------------------
# Wire menu autostart via .bash_profile snippet
# Idempotent using markers.
# -------------------------------
echo "[kidbox] Wiring menu autostart..."

BASH_PROFILE="$KID_HOME/.bash_profile"
SNIPPET="$REPO_ROOT/config/bash_profile_snippet.sh"

# Ensure .bash_profile exists
if [[ ! -f "$BASH_PROFILE" ]]; then
  touch "$BASH_PROFILE"
fi

MARK_BEGIN="# >>> kidbox menu autostart >>>"
MARK_END="# <<< kidbox menu autostart <<<"

# Remove any previous block
tmp="$(mktemp)"
awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
  $0==b {inblock=1; next}
  $0==e {inblock=0; next}
  !inblock {print}
' "$BASH_PROFILE" > "$tmp"
cat "$tmp" > "$BASH_PROFILE"
rm -f "$tmp"

# Append fresh block
{
  echo "$MARK_BEGIN"
  cat "$SNIPPET"
  echo "$MARK_END"
} >> "$BASH_PROFILE"

# -------------------------------
# Ownership
# -------------------------------
echo "[kidbox] Fixing ownership..."
chown -R "$KID_USER":"$KID_USER" "$KID_HOME/.xinitrc" "$KID_BIN_DIR" "$KIDBOX_DIR" "$BASH_PROFILE"

echo "[kidbox] Done."
