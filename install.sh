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

# Upstream DNS: CleanBrowsing Family Filter. Set KIDBOX_DNS="" to leave the
# machine's DNS alone. IPv6 is listed deliberately -- see the DNS section.
KIDBOX_DNS="${KIDBOX_DNS-185.228.168.168 185.228.169.168 2a0d:2a00:1:: 2a0d:2a00:2::}"

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
  zenity
  xterm
  alsa-utils
  chromium-browser
  mpg123
  console-setup
  kbd
  python3-evdev
  python3-tk
  xdotool
  dosbox
  curl
  unzip
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
# Starter files live apart from the kid's own work so a stray SAVE cannot
# overwrite them; presets is handed back to root below.
install -d -m 0755 "$KIDBOX_DIR/presets"

# -------------------------------
# Install scripts
# -------------------------------
echo "[kidbox] Installing scripts..."
for script in "$REPO_ROOT/bin/"*.sh; do
  if [[ -f "$script" ]]; then
    install -m 0755 "$script" "$KID_BIN_DIR/$(basename "$script")"
  fi
done

echo "[kidbox] Installing dictionary suggester..."
install -m 0755 "$REPO_ROOT/bin/dictionary-suggest.py" "$KID_BIN_DIR/dictionary-suggest.py"

echo "[kidbox] Installing screen-time bar..."
install -m 0755 "$REPO_ROOT/bin/kidbox-limit-bar.py" "$KID_BIN_DIR/kidbox-limit-bar.py"

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
# Install .xbindkeysrc-web (extra bindings, loaded only by site.sh)
# -------------------------------
echo "[kidbox] Installing .xbindkeysrc-web..."
install -m 0644 "$REPO_ROOT/config/xbindkeysrc-web" "$KID_HOME/.xbindkeysrc-web"

# Throwaway browser profiles live here; site.sh wipes its own on each launch.
install -d -m 0755 "$KID_HOME/.kidbox-browser"

# -------------------------------
# Install .Xresources
# -------------------------------
echo "[kidbox] Installing .Xresources..."
install -m 0644 "$REPO_ROOT/config/Xresources" "$KID_HOME/.Xresources"

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

# BASIC + Logo starters: safe to overwrite (they're templates). Files the kid
# saves land in kidbox/basic or kidbox/logo, next to nothing they can break:
# the menu starts BASIC in kidbox/basic, and welcome.lg points Logo's SETPREFIX
# at kidbox/logo.
install -m 0644 "$REPO_ROOT/content/basic/HELLO.BAS" "$KIDBOX_DIR/presets/HELLO.BAS"
install -m 0644 "$REPO_ROOT/content/logo/welcome.lg" "$KIDBOX_DIR/presets/welcome.lg"
rm -f "$KIDBOX_DIR/basic/HELLO.BAS" "$KIDBOX_DIR/logo/welcome.lg"

# DOS games. Settings are a preset (root-owned, like the starters above).
#
# The game files are not in git: the repo is public and they are not ours to
# publish. Each game is fetched from the URL below and checked against its
# SHA-256, so the box gets exactly the files that were tested. A game already
# installed is left alone, so high scores and saved stories survive a
# reinstall; delete its folder under kidbox/dos to take a fresh copy.
#
# The links are Internet Archive items (archive.org/details/<item>), which
# are meant to be permanent, but a failed download is still only a warning,
# not a failed install. To install by hand instead (from a USB drive, say),
# put the game in content/dos as either
#   content/dos/<folder>/      the files, with the program at the top, or
#   content/dos/<folder>.zip   the zip, unzipped (flattened) into the above
# and either is used in place of the download, with no checksum check. Both
# are kept out of git. The menu shows a game only once it is installed.
DOS_GAMES=(
  # Taken from a school's network install: CONFIG.CLS and HMS306.ITM belong
  # to that, and the game does not use them.
  "oregon-trail|https://archive.org/download/msdos_Oregon_Trail_The_1990/Oregon_Trail_The_1990.zip|516a215af2023b771587bbd425d620e6be8d208cf5ea1651ffab36adf1a9774b"
  "adventures-in-math|https://archive.org/download/msdos_Adventures_in_Math_1983/Adventures_in_Math_1983.zip|232981feb8e0b87a2154a1327636254bcc75d0ff19fab594c42dcc997182f5d9"
)

# Unzip a game into a new folder, flattening any folders inside the zip so
# the program is at the top. The work happens in a hidden folder next to the
# destination, so a failure part-way never leaves a half-made game folder.
# Usage: unzip_dos_game <zip> <dest>
unzip_dos_game() {
  local zip="$1" dest="$2" tmp
  tmp="$(mktemp -d "$(dirname "$dest")/.unzip.XXXXXX")"
  if unzip -q -j "$zip" -d "$tmp/files"; then
    mv "$tmp/files" "$dest"
    rm -rf "$tmp"
    return 0
  fi
  rm -rf "$tmp"
  return 1
}

# Download a game, check it against its SHA-256 and unzip it into place.
# Usage: fetch_dos_game <dest> <url> <sha256>
fetch_dos_game() {
  local dest="$1" url="$2" sha="$3" tmp status=1
  tmp="$(mktemp -d "$(dirname "$dest")/.download.XXXXXX")"
  if curl -fsSL --retry 2 -A "kidbox-install" -o "$tmp/game.zip" "$url" \
      && echo "$sha  $tmp/game.zip" | sha256sum -c --quiet - \
      && unzip_dos_game "$tmp/game.zip" "$dest"; then
    status=0
  fi
  rm -rf "$tmp"
  return $status
}

install -m 0644 "$REPO_ROOT/config/dosbox.conf" "$KIDBOX_DIR/presets/dosbox.conf"
install -d -m 0755 "$KIDBOX_DIR/dos"
for entry in "${DOS_GAMES[@]}"; do
  IFS='|' read -r folder url sha <<< "$entry"
  dest="$KIDBOX_DIR/dos/$folder"
  local_dir="$REPO_ROOT/content/dos/$folder"
  if [[ -d "$dest" ]]; then
    echo "[kidbox]   $folder: already installed, keeping it"
    continue
  fi

  if [[ ! -d "$local_dir" && -f "$local_dir.zip" ]]; then
    echo "[kidbox]   $folder: unzipping content/dos/$folder.zip"
    unzip_dos_game "$local_dir.zip" "$local_dir" \
      || echo "[kidbox]   WARNING: could not unzip $folder.zip" >&2
  fi

  if [[ -d "$local_dir" ]]; then
    echo "[kidbox]   $folder: copying from content/dos"
    cp -r "$local_dir" "$dest"
  elif fetch_dos_game "$dest" "$url" "$sha"; then
    echo "[kidbox]   $folder: downloaded"
  else
    echo "[kidbox]   WARNING: could not download or verify $folder; it will" >&2
    echo "[kidbox]   not be in the menu. See the DOS games notes in install.sh." >&2
  fi
done

# Book PDF: copy if exists
if [[ -f "$REPO_ROOT/doc/kidbook.pdf" ]]; then
  install -m 0644 "$REPO_ROOT/doc/kidbook.pdf" "$KIDBOX_DIR/kidbook.pdf"
fi

# Dictionary: built by tools/build-dictionary.py and committed, so the Pi
# never needs the source data or a build step.
if [[ -f "$REPO_ROOT/content/dictionary.txt" ]]; then
  install -m 0644 "$REPO_ROOT/content/dictionary.txt" "$KIDBOX_DIR/dictionary.txt"
fi

# Clock HTML: copy if exists
if [[ -f "$REPO_ROOT/content/clock.html" ]]; then
  install -m 0644 "$REPO_ROOT/content/clock.html" "$KIDBOX_DIR/clock.html"
fi

# Timer sounds: copy if exist
if [[ -f "$REPO_ROOT/content/timer.mp3" ]]; then
  install -m 0644 "$REPO_ROOT/content/timer.mp3" "$KIDBOX_DIR/timer.mp3"
fi
if [[ -f "$REPO_ROOT/content/alarm.mp3" ]]; then
  install -m 0644 "$REPO_ROOT/content/alarm.mp3" "$KIDBOX_DIR/alarm.mp3"
fi

# -------------------------------
# DNS
#
# Point the machine at a filtering resolver. This is a backstop, not the main
# boundary -- the Chromium allowlist is that, and it already blocks everything
# not named in sites.conf. DNS filtering earns its place by covering the case
# where the policy does not load at all (the managed-policy directory name
# differs per browser build, which is why the generator writes two of them).
#
# Both IPv4 and IPv6 servers are set. Setting only IPv4 leaves the filter open
# on any network that hands out IPv6: the router advertises its own resolver,
# the box happily uses it, and nothing looks wrong.
#
# The kid user cannot undo this -- its only sudo right is /sbin/shutdown.
# -------------------------------
if [[ -n "$KIDBOX_DNS" ]]; then
  echo "[kidbox] Configuring DNS..."

  if systemctl is-active --quiet NetworkManager; then
    # Bookworm and later. A global-dns section overrides whatever DHCP offers,
    # for every connection, so this does not need to name an interface.
    install -d -m 0755 /etc/NetworkManager/conf.d
    {
      echo "# Managed by kidbox install.sh. Edits here are overwritten."
      echo "[global-dns-domain-*]"
      echo "servers=$(echo "$KIDBOX_DNS" | tr ' ' ',')"
    } > /etc/NetworkManager/conf.d/kidbox-dns.conf
    chmod 0644 /etc/NetworkManager/conf.d/kidbox-dns.conf
    systemctl reload-or-restart NetworkManager
    echo "[kidbox]   NetworkManager: $KIDBOX_DNS"

  elif systemctl is-active --quiet dhcpcd; then
    # Bullseye and earlier. Idempotent using markers, as with .bash_profile.
    DNS_BEGIN="# >>> kidbox dns >>>"
    DNS_END="# <<< kidbox dns <<<"
    tmp="$(mktemp)"
    awk -v b="$DNS_BEGIN" -v e="$DNS_END" '
      $0==b {inblock=1; next}
      $0==e {inblock=0; next}
      !inblock {print}
    ' /etc/dhcpcd.conf > "$tmp"
    cat "$tmp" > /etc/dhcpcd.conf
    rm -f "$tmp"
    {
      echo "$DNS_BEGIN"
      echo "static domain_name_servers=$KIDBOX_DNS"
      echo "$DNS_END"
    } >> /etc/dhcpcd.conf
    systemctl restart dhcpcd
    echo "[kidbox]   dhcpcd: $KIDBOX_DNS"

  else
    echo "[kidbox]   WARNING: neither NetworkManager nor dhcpcd is running." >&2
    echo "[kidbox]   DNS was NOT changed. Set it on the router instead." >&2
  fi
fi

# -------------------------------
# Website list + Chromium allowlist
#
# config/sites.conf in the repo is the single source of truth, for both the
# website menu (menu.sh reads the installed copy directly) and the browser's
# managed policy. This overwrites the installed copy every run: a site is
# added by editing the repo and reinstalling, never by editing the file on the
# machine. Unlike the typing files above, nothing here is kid-written, so
# there is nothing to preserve -- and preserving it would silently strand the
# machine on an old allowlist while the install still reported success.
# -------------------------------
echo "[kidbox] Installing website list..."

install -d -m 0755 /etc/kidbox
install -m 0644 "$REPO_ROOT/config/sites.conf" /etc/kidbox/sites.conf

echo "[kidbox] Generating Chromium policy..."
install -m 0755 "$REPO_ROOT/bin/kidbox-gen-policy.py" "/usr/local/bin/kidbox-gen-policy.py"
/usr/local/bin/kidbox-gen-policy.py

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
chown -R "$KID_USER":"$KID_USER" "$KID_HOME/.xinitrc" "$KID_HOME/.xbindkeysrc" "$KID_HOME/.xbindkeysrc-web" "$KID_HOME/.Xresources" "$KID_HOME/.kidbox-browser" "$KID_BIN_DIR" "$KIDBOX_DIR" "$BASH_PROFILE"
# Read-only for the kid: root-owned files in a root-owned directory.
chown -R root:root "$KIDBOX_DIR/presets"

# -------------------------------
# Sudoers: Allow kid user to shutdown
# -------------------------------
echo "[kidbox] Configuring shutdown permissions..."
SUDOERS_FILE="/etc/sudoers.d/kidbox-shutdown"
cat > "$SUDOERS_FILE" <<EOF
# Allow kid user to shutdown without password
$KID_USER ALL=(ALL) NOPASSWD: /sbin/shutdown -h now
EOF

# Validate sudoers syntax before enabling it
if ! visudo -c -f "$SUDOERS_FILE"; then
  echo "[kidbox] Error: invalid sudoers configuration in $SUDOERS_FILE" >&2
  rm -f "$SUDOERS_FILE"
  exit 1
fi
chmod 0440 "$SUDOERS_FILE"

# -------------------------------
# Power Button Handling
# -------------------------------
echo "[kidbox] Configuring power button handling..."

# Install systemd-logind drop-in configuration
LOGIND_DROPIN_DIR="/etc/systemd/logind.conf.d"
install -d -m 0755 "$LOGIND_DROPIN_DIR"
install -m 0644 "$REPO_ROOT/config/systemd/kidbox-power.conf" "$LOGIND_DROPIN_DIR/kidbox-power.conf"

# Install power menu script
install -m 0755 "$REPO_ROOT/bin/kidbox-power-menu.sh" "/usr/local/bin/kidbox-power-menu.sh"

# Install power button watcher script
install -m 0755 "$REPO_ROOT/bin/kidbox-power-watch.py" "/usr/local/bin/kidbox-power-watch.py"

# Install systemd service
install -m 0644 "$REPO_ROOT/config/systemd/kidbox-power-watch.service" "/etc/systemd/system/kidbox-power-watch.service"

# Reload systemd daemon to pick up new service
systemctl daemon-reload

# Enable and start power button watcher service
systemctl enable kidbox-power-watch.service
systemctl restart kidbox-power-watch.service

# Restart systemd-logind to pick up new configuration
# Note: This will briefly disconnect any logged-in sessions
echo "[kidbox] Restarting systemd-logind to apply power button configuration..."
systemctl restart systemd-logind.service

echo "[kidbox] Power button configuration complete."
echo "[kidbox] - Short press: shows Power menu (Shutdown/Cancel)"
echo "[kidbox] - Long press (2+ seconds): immediate poweroff"

echo "[kidbox] Done."
