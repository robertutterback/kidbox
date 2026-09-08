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
- Dictionary: Offline word lookup with kid-readable definitions, plus spelling suggestions on a miss
- Book: View the instruction book (Chromium kiosk mode - evince was tried but took ~60s to load, xpdf is too hard for kids)
- Websites: A configurable list of approved sites (Chromium kiosk mode, no address bar, machine-wide allowlist)

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

## Building the Books

There are two books in `doc/`:

- `kidbook.tex` — the short instruction book for the whole computer.
- `turtlebook.tex` — a longer, guided Logo book for a stronger reader,
  written to be read alone. (A BASIC book is planned separately; the
  BASIC programs under `doc/programs/basic/` are kept for it.)

If you need to rebuild them, I recommend doing it on a normal development
machine, unless you really want to install texlive on your Pi.

```bash
cd doc
make
```

Every program printed in the turtle book lives in `doc/programs/`, and every
picture in `doc/figures/` was drawn by running that program. After changing a
program, re-run the check on a development machine (it needs `ucblogo`,
`pcbasic`, Xvfb, `xdotool`, ImageMagick, ghostscript and `pdfcrop`):

```bash
./tools/check-programs.sh          # or: make -C doc check
./tools/check-programs.sh fill     # just one program
```

It fails if any program errors or hangs, and rewrites the figures otherwise.
A Logo program that reads the keyboard gets a `.keys` file beside it with
the keys to press. Most figures are vector exports; the ones that need a
real screenshot (fills, labels) are listed at the top of the script.

## Printing the Booklet

The `doc/kidbook-booklet.pdf` is pre-imposed for booklet printing:

1. Print **duplex** (double-sided) with **long-edge binding** (flip on long edge)
2. Fold the printed stack in half **horizontally** (bring top edge to bottom edge)
3. Staple along the center fold

The pages are already arranged in the correct order for this to work.

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

## Dictionary

`content/dictionary.txt` is a plain tab-separated file — word, part of speech,
definition — with about 48,700 words. Lookup is one pass of `awk`, and a miss
runs `bin/dictionary-suggest.py` to offer close spellings. No daemon, no
`dict` client, no network: the earlier `dictd` version could fall back to
public servers at dict.org and hang on every typo.

### Where the definitions come from

Simple English Wiktionary, which is written by hand for people learning
English. That matters more than it sounds: WordNet defines a cat as "a small
domesticated carnivorous mammal", while Simple English Wiktionary says "A cat
is a domestic animal often kept as a pet; it has whiskers and likes to chase
mice." Debian has no kid-friendly dictionary package — the alternatives are
WordNet, Webster's 1913, and three glossaries of computing acronyms.

Definitions are used under **CC BY-SA 4.0**, so the derived file is under the
same licence. Attribution is in the file header. The repo has no `LICENSE`
file yet; if you add one, this file is the constraint to check first.

### Rebuilding

```bash
./tools/build-dictionary.py
```

Downloads the source data (~6MB) and rewrites `content/dictionary.txt`. Run it
on a development machine — the built file is committed, so the Pi never needs
the source data or a build step.

The build filters out proper nouns, non-alphabetic entries, senses Wiktionary
itself labels Vulgar/Slang/Sex, and any word or definition mentioning a term
from a standard profanity list. That last filter matters: filtering headwords
alone still let a kid meet a blocked word inside the definition of an innocent
one. Roughly 1,100 entries are dropped.

This is a filter, not a guarantee. The point of shipping a plain text file is
that you can audit it:

```bash
cut -f1 content/dictionary.txt | sort -u | less   # every word in it
grep -i '<TAB>.*something' content/dictionary.txt # what a definition says
```

Delete any line you object to. Nothing needs rebuilding — the lookup script
reads the file as it is.

## Websites

Website menu items are defined in `config/sites.conf` **in this repo**. Each
line is either a menu item or an allowlist entry:

```
SITE|IXL (School Practice)|https://www.ixl.com/signin|ixl.com
ALLOW|starfall.com,abcya.com
```

The repo copy is the source of truth. `install.sh` copies it to
`/etc/kidbox/sites.conf`, overwriting what is there, then regenerates the
browser policy from it. So the workflow for adding a site is:

```bash
# edit config/sites.conf, commit, then on the Pi:
sudo ./install.sh
```

Do not edit `/etc/kidbox/sites.conf` on the machine — the next install
overwrites it. `menu.sh` reads that installed copy every time the menu is
drawn, and `kidbox-gen-policy.py` turns it into the Chromium policy; you can
run that generator alone (`sudo kidbox-gen-policy.py`) if you are only
rebuilding the policy from an already-installed config.

### DNS

`install.sh` points the machine at [CleanBrowsing's Family
Filter](https://cleanbrowsing.org/filters/), IPv4 and IPv6:

```
185.228.168.168   185.228.169.168
2a0d:2a00:1::     2a0d:2a00:2::
```

It writes `/etc/NetworkManager/conf.d/kidbox-dns.conf` on Bookworm and later,
or a marked block in `/etc/dhcpcd.conf` on Bullseye, picking whichever service
is actually running. If neither is, it warns and changes nothing rather than
writing a `/etc/resolv.conf` that the next DHCP lease overwrites.

Override with `sudo KIDBOX_DNS="1.1.1.3 1.0.0.3" ./install.sh`, or
`KIDBOX_DNS=""` to leave the machine's DNS alone.

Two things worth knowing:

- **This is a backstop, not the boundary.** The Chromium allowlist is the
  boundary and it already blocks everything not in `sites.conf`. DNS filtering
  earns its keep by covering the case where the policy fails to load at all.
- **IPv6 is set on purpose.** Configuring only the IPv4 servers leaves the
  filter wide open on any network handing out IPv6 — the router advertises its
  own resolver, the Pi uses it, and nothing appears wrong.

The policy also sets `DnsOverHttpsMode: "off"`. Chromium otherwise resolves
names over its own DoH connection, which never touches the system resolver and
would sail straight past the filter. CleanBrowsing documents this as a
[required hardening step](https://cleanbrowsing.org/support/troubleshooting/harden-chrome).

The kid user cannot undo any of it — its only sudo right is
`/sbin/shutdown -h now`.

### How the lockdown works

Sites open with `chromium-browser --kiosk --app=URL`, which means no address
bar and no window frame. That is a UI restriction, not a boundary — it stops
typing a URL, not clicking a link.

The boundary is a Chromium managed policy generated from `sites.conf`:
`URLBlocklist: ["*"]` plus an allowlist of the configured domains. It is
written to both `/etc/chromium/policies/managed/` and
`/etc/chromium-browser/policies/managed/`, because the directory name depends
on the browser build and Raspberry Pi OS and Debian disagree about it.

The policy applies to **every** Chromium launch on the machine, not just
website menu items — there is no state in which the allowlist is off. This is
why `file://*` is allowlisted: the Clock and the Book are `file://` URLs and
would otherwise be blocked. The policy also disables downloads, printing,
devtools, popups, sign-in, sync, the password manager, autofill, and camera,
mic and geolocation access.

To inspect what the browser actually loaded, open `chrome://policy` **as your
own user** (that URL is blocked for the kid user).

### Notes and known limits

- **Browsing is stateless.** Each launch wipes its profile under
  `~/.kidbox-browser/<slug>/`, so no cookies, logins or cache survive a
  session — nothing accumulates on the SD card.
- **Volume starts at 100%** on every launch, so the timer alarm is loud.
  Inside any app, the keyboard's volume keys or `Ctrl+Alt+Up` / `Down` (and
  `Ctrl+Alt+M` to mute) adjust it via `bin/kidbox-volume.sh`; the change
  lasts until the next launch.
- **Esc goes back.** Kiosk + app mode has no back button, so a kid who
  clicks a link to a blocked domain would be stranded on the block page.
  `~/.xbindkeysrc-web` maps Esc to Alt+Left, and is loaded only while a
  website is open. `Alt+Left` works natively too.
- **Asset domains.** If pages render broken, Chromium is applying the
  blocklist to subresources and not just navigation. The fix is to add the
  CDN domains a site pulls from to an `ALLOW` line; `sites.conf` ships with
  the common ones.
- **Search engines and video sites are deliberately absent.** A search engine
  reaches everything, which defeats the allowlist.

## Power Button Behavior

The physical power button is configured for safe, deliberate shutdown:

- **Short press (< 2 seconds)**: Shows a Power menu with options:
  - Shutdown
  - Cancel
- **Long press (≥ 2 seconds)**: Immediate poweroff (emergency override)

This prevents accidental shutdown from a quick button press while still allowing intentional shutdown through the menu or emergency poweroff via long press.

### Implementation Details

The power button handling uses:
- **systemd-logind configuration** (`/etc/systemd/logind.conf.d/kidbox-power.conf`) - Tells systemd to ignore short power button presses
- **Power button watcher service** (`kidbox-power-watch.service`) - Monitors the power button and detects short vs long press
- **Power menu script** (`/usr/local/bin/kidbox-power-menu.sh`) - Displays the whiptail menu on short press

### Troubleshooting

To view power button monitor logs:
```bash
sudo journalctl -u kidbox-power-watch -f
```

To check power button watcher status:
```bash
sudo systemctl status kidbox-power-watch
```

To temporarily disable power button handling (revert to default immediate shutdown):
```bash
sudo systemctl stop kidbox-power-watch
sudo rm /etc/systemd/logind.conf.d/kidbox-power.conf
sudo systemctl restart systemd-logind
```

To re-enable (or after updating):
```bash
cd kidbox
git pull
sudo ./install.sh
```

## Notes

- Set `KID_USER` to set the name of the <kiduser>.
- The menu lives at `/home/<kiduser>/bin/menu.sh`
- The minimal X session lives at `/home/<kiduser>/.xinitrc`
- Content lives in `/home/<kiduser>/kidbox`
- Logs are stored in `/home/<kiduser>/.kidbox-logs/YYYY-MM-DD.log`

