# kidbox

A locked-down, retro-style kid computer setup for Raspberry Pi:

- Boots to console
- Auto-launches a simple menu
- Launches minimal X only for selected programs

MVP Activities:
- Logo: UCBLogo
- BASIC: PC-BASIC (GW-BASIC-like)
- Typing: Leafpad (separate files for Sally & Penny)
- Drawing: Tux Paint
- Clock: Custom HTML/CSS/JS analog + digital (Chromium kiosk mode)
- Timer: Visual countdown with looping background music and alarm
- Stopwatch: Count-up timer
- Book: View the instruction book (evince)

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

## Building the Book

If you need to rebuild the instruction book (`doc/kidbook.tex`), I
recommend doing it on a normal development machine, unless you really
want to install texlive on your Pi.

```bash
cd doc
make
```

You can print out `doc/kidbook-booklet.pdf` to make a little booklet.

## Timer Sounds

The timer supports two optional sound files:

- **`content/timer.mp3`** - Loops during the countdown (background music)
- **`content/alarm.mp3`** - Plays when the timer finishes (alarm sound)

The included timer sounds are from [Mixkit](https://mixkit.co) and are subject to the [Mixkit Sound Effects Free License](https://mixkit.co/license/#sfxFree).

To use custom sounds:

1. Add your own mp3 files to the `content/` directory
2. Run `sudo ./install.sh` to copy them to the kid's home directory
3. The timer will automatically use them

If no custom sounds exist, the countdown is silent and the alarm falls back to system beeps.

## Notes

- Set `KID_USER` to set the name of the <kiduser>.
- The menu lives at `/home/<kiduser>/bin/menu.sh`
- The minimal X session lives at `/home/<kiduser>/.xinitrc`
- Content lives in `/home/<kiduser>/kidbox`

