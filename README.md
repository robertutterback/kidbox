# kidbox

A retro-style kid computer setup for Raspberry Pi:
- Boots to console
- Auto-launches a simple menu
- Launches minimal X only for selected programs

MVP Activities:
- Logo: UCBLogo
- BASIC: PC-BASIC (GW-BASIC-like)
- Typing (w/ color color): Leafpad
- Drawing: Tux Paint

## Install

1. Clone and run install script:
```bash
git clone <REPO_URL> kidbox
cd kidbox
sudo KID_USER=girls ./install.sh
```
2. Set auto-login to console for the kid user:

```
sudo raspi-config
# System Options -> Boot / Auto Login -> Console AutoLogin
```

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

