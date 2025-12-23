# kidbox

A locked-down, retro-style kid computer setup for Raspberry Pi:

- Boots to console
- Auto-launches a simple menu
- Launches minimal X only for selected programs

MVP Activities:
- Logo: UCBLogo
- BASIC: PC-BASIC (GW-BASIC-like)
- Typing (w/ color color): Leafpad
- Drawing: Tux Paint
- Clock: Analog (xclock) + Digital (tty-clock)
- Timer: Visual countdown with sound

Intentionally simple and explicit. The idea is that the only way to
use such a computer is to start understanding how it works.

## Install

1. Clone and run install script:
```bash
git clone <REPO_URL> kidbox
cd kidbox
sudo KID_USER=girls ./install.sh
```

2. Set console auto-login (can't use raspi-config b/c it will do it for your user)

```bash
sudo systemctl edit getty@tty1
```

```ini
[Service]
ExecStart= # clear default ExecStart inherited from the unit
ExecStart=-/sbin/agetty --autologin <kiduser> --noclear %I $TERM
```

3. Reboot

## Update

```bash
git pull
sudo ./install.sh
```

## Notes

- Set `KID_USER` to set the name of the <kiduser>.
- The menu lives at `/home/<kiduser>/bin/menu.sh`
- The minimal X session lives at `/home/<kiduser>/.xinitrc`
- Content lives in `/home/<kiduser>/kidbox`

