#!/usr/bin/env python3
"""Experiment: a countdown banner across the top, with the app pushed down
so nothing overlaps.

kidbox runs no window manager (see config/xinitrc), so nobody reserves
screen space and nobody stops us doing it ourselves. The banner finds the
app window -- the one visible window sized to the whole screen -- and
moves it down by the banner's height with xdotool, then keeps checking:
Chromium --kiosk sizes itself to the screen and may put itself back, and
that is one of the things this test is meant to find out. With no WM,
stacking is map order and any app may raise itself, so the banner also
re-raises itself every tick.

One thing to watch for with no WM: keyboard focus follows the pointer. If
the mouse is parked over the banner, keystrokes go to it, not to the app.
unclutter hides the pointer but does not move it.

Not installed by install.sh. From an admin shell (SSH, or a console logged
in as yourself -- the kid user has no password and its login runs the
menu), with a website open on the Pi:

  1. sudo apt-get install python3-tk        (once; not in APT_PACKAGES yet)
  2. sudo install -m 755 bin/dock-test.py /home/girls/bin/
  3. sudo -H -u girls DISPLAY=:1 /home/girls/bin/dock-test.py 120
  4. Look at the Pi's screen.

Expected: a slim blue banner along the top with a ticking clock, the page
starting directly beneath it with nothing hidden, staying that way while
you scroll and click. Red under a minute. The console prints each tick and
a line every time the app window had to be pushed back into place; more
than one of those means Chromium is fighting.

Options:
  seconds       how long to count down (default 120)
  --height N    banner height in pixels (default 32)
  --no-push     leave the app where it is (banner overlaps it)
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


def xdo(*args):
  """Run xdotool, returning stdout; empty string on failure."""
  try:
    return subprocess.run(["xdotool", *args], capture_output=True,
                          text=True, check=True).stdout
  except (subprocess.CalledProcessError, FileNotFoundError):
    return ""


def geometry(wid):
  """(x, y, width, height) of a window, or None if it is gone."""
  out = xdo("getwindowgeometry", "--shell", wid)
  if not out:
    return None
  g = dict(line.split("=", 1) for line in out.split())
  return int(g["X"]), int(g["Y"]), int(g["WIDTH"]), int(g["HEIGHT"])


def find_app_window(screen_w, screen_h):
  """The visible window that fills (or nearly fills) the screen."""
  for wid in xdo("search", "--onlyvisible", "--name", ".*").split():
    if xdo("getwindowname", wid).strip() == TITLE:
      continue
    g = geometry(wid)
    if g and g[2] >= screen_w * 0.9 and g[3] >= screen_h * 0.8:
      return wid
  return None


def main():
  ap = argparse.ArgumentParser()
  ap.add_argument("seconds", nargs="?", type=int, default=120)
  ap.add_argument("--height", type=int, default=32)
  ap.add_argument("--no-push", action="store_true")
  ap.add_argument("--kill", action="store_true")
  args = ap.parse_args()
  height = args.height

  root = tk.Tk()
  root.title(TITLE)
  screen_w = root.winfo_screenwidth()
  screen_h = root.winfo_screenheight()
  root.geometry(f"{screen_w}x{height}+0+0")
  # Harmless with no WM; keeps a WM from decorating or moving it if one is
  # ever added.
  root.overrideredirect(True)

  root.configure(bg=BLUE)
  label = tk.Label(root, bg=BLUE, fg="white",
                   font=("DejaVu Sans", max(10, height // 2), "bold"))
  label.pack(expand=True, fill="both")

  state = {"left": args.seconds, "app": None}
  want = (0, height, screen_w, screen_h - height)

  def push_app():
    """Keep the app window directly under the banner."""
    wid = state["app"]
    g = geometry(wid) if wid else None
    if g is None:
      wid = state["app"] = find_app_window(screen_w, screen_h)
      g = geometry(wid) if wid else None
    if g is None or g == want:
      return
    xdo("windowmove", wid, str(want[0]), str(want[1]))
    xdo("windowsize", wid, str(want[2]), str(want[3]))
    print(f"pushed window {wid}: {g} -> {want}", flush=True)

  def tick():
    left = state["left"]
    mins, secs = divmod(left, 60)
    label.config(text=f"Time left today:  {mins:02d}:{secs:02d}")
    if left <= WARN_SECS:
      root.configure(bg=RED)
      label.config(bg=RED)
    print(f"{mins:02d}:{secs:02d}", flush=True)

    if not args.no_push:
      push_app()
    # Nothing else keeps us on top.
    root.lift()

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
