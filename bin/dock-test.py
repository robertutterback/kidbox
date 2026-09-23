#!/usr/bin/env python3
"""Experiment: a countdown strip that stays on screen over a running app.

kidbox runs no window manager (see config/xinitrc), so nothing reserves
screen space for a panel: the app covers the whole screen and the strip
has to sit on top of it. With no WM, stacking is map order and any app may
raise itself, so the strip re-raises every tick. It covers a 48px band of
the app underneath -- the bottom edge by default, where a web page has the
least going on.

One thing to watch for with no WM: keyboard focus follows the pointer. If
the mouse is parked over the strip, keystrokes go to it, not to the app.
unclutter hides the pointer but does not move it.

Not installed by install.sh. From an admin shell (SSH, or a console logged
in as yourself -- the kid user has no password and its login runs the
menu), with a website open on the Pi:

  1. sudo apt-get install python3-tk        (once; not in APT_PACKAGES yet)
  2. sudo install -m 755 bin/dock-test.py /home/girls/bin/
  3. sudo -H -u girls DISPLAY=:1 /home/girls/bin/dock-test.py 120
  4. Look at the Pi's screen.

Expected: a blue strip along the bottom with a ticking clock, over the
page, staying put while you scroll and click. Red under a minute. Watch
for flicker (the once-a-second raise) and for the focus problem above.

Options:
  seconds       how long to count down (default 120)
  --top         put the strip along the top edge instead
  --kill        at zero, run "pkill -TERM Xorg" (what Ctrl+Alt+Backspace
                does) so the session ends and the menu comes back
"""

import argparse
import subprocess
import sys
import tkinter as tk

HEIGHT = 48
WARN_SECS = 60
BLUE = "#1d3557"
RED = "#c1121f"


def main():
  ap = argparse.ArgumentParser()
  ap.add_argument("seconds", nargs="?", type=int, default=120)
  ap.add_argument("--top", action="store_true")
  ap.add_argument("--kill", action="store_true")
  args = ap.parse_args()

  root = tk.Tk()
  root.title("kidbox-dock-test")
  width = root.winfo_screenwidth()
  y = 0 if args.top else root.winfo_screenheight() - HEIGHT
  root.geometry(f"{width}x{HEIGHT}+0+{y}")
  # Harmless with no WM; keeps a WM from decorating or moving it if one is
  # ever added.
  root.overrideredirect(True)

  root.configure(bg=BLUE)
  label = tk.Label(root, bg=BLUE, fg="white", font=("DejaVu Sans", 22, "bold"))
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
