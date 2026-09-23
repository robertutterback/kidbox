#!/usr/bin/env python3
"""Experiment: a countdown strip that sits beside a running app, with the
app shrunk to make room.

Matchbox shows one application window at a time, sized to fill the screen,
so a plain xterm or xmessage cannot share the display with Chromium. Two
window types are exceptions and matchbox shrinks the app around them:

  toolbar  (_NET_WM_WINDOW_TYPE_TOOLBAR)  always along the bottom edge
  dock     (_NET_WM_WINDOW_TYPE_DOCK)     edge chosen from its geometry

The difference that matters: Chromium --kiosk is a FULLSCREEN client, and
for those matchbox ignores docks (a dock ends up drawn over the page) but
still subtracts toolbars. So toolbar is the default here. Tk sets the type
with attributes('-type', ...). This script does exactly that, so the idea
can be proved on the Pi before a time-limit feature is built on it.

Matchbox needs to be running -- on bare X nothing reserves space and
nothing grants Chromium's fullscreen request either, so the first thing
printed is whether it is.

Not installed by install.sh. From an admin shell (SSH, or a console logged
in as yourself -- the kid user has no password and its login runs the
menu), with a website open on the Pi:

  1. sudo apt-get install python3-tk        (once; not in APT_PACKAGES yet)
  2. sudo install -m 755 bin/dock-test.py /home/girls/bin/
  3. sudo -H -u girls DISPLAY=:1 /home/girls/bin/dock-test.py 120
  4. Look at the Pi's screen.

Expected: a slim blue strip along the bottom with a ticking clock, and the
page resized to end directly above it, reaching both side edges, with
nothing hidden. Red under a minute. The console prints the window manager
and every top-level window with its geometry at startup, then a tick per
second.

Options:
  seconds       how long to count down (default 120)
  --height N    strip height in pixels (default 32)
  --type T      toolbar (default) or dock; see above
  --kill        at zero, run "pkill -TERM Xorg" (what Ctrl+Alt+Backspace
                does) so the session ends and the menu comes back
"""

import argparse
import subprocess
import sys
import tkinter as tk

TITLE = "kidbox-dock-test"
WARN_SECS = 60
BLUE = "#1d3557"
RED = "#c1121f"


def run(*cmd):
  """Run a command, returning stdout; empty string on failure."""
  try:
    return subprocess.run(cmd, capture_output=True, text=True,
                          check=True).stdout
  except (subprocess.CalledProcessError, FileNotFoundError):
    return ""


def report_environment():
  wm = run("pgrep", "-a", "matchbox").strip()
  print(f"window manager: {wm or 'NONE -- matchbox is not running'}", flush=True)
  print("top-level windows:", flush=True)
  for wid in run("xdotool", "search", "--maxdepth", "1", "--onlyvisible",
                 "--name", ".*").split():
    geo = run("xdotool", "getwindowgeometry", "--shell", wid)
    if not geo:
      continue
    g = dict(line.split("=", 1) for line in geo.split())
    name = run("xdotool", "getwindowname", wid).strip()
    print(f"  {wid:>10}  {g['WIDTH']}x{g['HEIGHT']}+{g['X']}+{g['Y']}  [{name}]",
          flush=True)


def main():
  ap = argparse.ArgumentParser()
  ap.add_argument("seconds", nargs="?", type=int, default=120)
  ap.add_argument("--height", type=int, default=32)
  ap.add_argument("--type", choices=["toolbar", "dock"], default="toolbar")
  ap.add_argument("--kill", action="store_true")
  args = ap.parse_args()
  height = args.height

  report_environment()

  root = tk.Tk()
  root.title(TITLE)
  # Toolbars go along the bottom whatever we ask for; a dock takes its edge
  # from where we put it, so ask for the bottom in both cases.
  y = root.winfo_screenheight() - height
  root.geometry(f"{root.winfo_screenwidth()}x{height}+0+{y}")
  # Must be set before the window is first mapped, which is why it comes
  # before mainloop() and before any update().
  root.attributes("-type", args.type)

  root.configure(bg=BLUE)
  label = tk.Label(root, bg=BLUE, fg="white",
                   font=("DejaVu Sans", max(10, height // 2), "bold"))
  label.pack(expand=True, fill="both")

  state = {"left": args.seconds}

  def tick():
    left = state["left"]
    mins, secs = divmod(left, 60)
    label.config(text=f"Time left today:  {mins:02d}:{secs:02d}")
    if left <= WARN_SECS:
      root.configure(bg=RED)
      label.config(bg=RED)
    print(f"{mins:02d}:{secs:02d}", flush=True)

    if left <= 0:
      label.config(text="All done for today!")
      root.update()
      if args.kill:
        subprocess.run(["pkill", "-TERM", "Xorg"], check=False)
      root.after(3000, root.destroy)
      return

    state["left"] = left - 1
    root.after(1000, tick)

  tick()
  root.mainloop()
  return 0


if __name__ == "__main__":
  sys.exit(main())
