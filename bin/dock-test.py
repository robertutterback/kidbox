#!/usr/bin/env python3
"""Experiment: can a countdown strip sit on screen beside a running app?

Matchbox shows one application window at a time, sized to fill the screen,
so a plain xterm or xmessage cannot share the display with Chromium. The
exception is a window of type _NET_WM_WINDOW_TYPE_DOCK: matchbox pins it to
a screen edge and shrinks the app to fit around it. Tk sets that type with
attributes('-type', 'dock'). This script tries exactly that, and nothing
else, so the idea can be proved on the Pi before a time-limit feature is
built on it.

Not installed by install.sh. The kid user has no password and its login
shell runs the menu, so drive this from an admin shell (SSH, or another
console) with sudo. With a website open on the Pi:

  1. sudo apt-get install python3-tk        (once; not in APT_PACKAGES yet)
  2. sudo install -m 755 bin/dock-test.py /home/girls/bin/
  3. sudo -H -u girls DISPLAY=:1 /home/girls/bin/dock-test.py 120
  4. Look at the Pi's screen.

Expected: a strip across the top with a ticking clock, and Chromium
resized to sit below it. If Chromium instead covers the strip, kiosk
mode's own fullscreen is winning; try --override, which bypasses the
window manager entirely and re-raises itself every tick.

Options:
  seconds       how long to count down (default 120)
  --bottom      pin to the bottom edge instead of the top
  --override    unmanaged override-redirect window instead of a dock
  --kill        at zero, run "pkill -TERM Xorg" (what Ctrl+Alt+Backspace
                does) so the session ends and the menu comes back
"""

import argparse
import subprocess
import sys
import tkinter as tk

HEIGHT = 64
WARN_SECS = 60


def main():
  ap = argparse.ArgumentParser()
  ap.add_argument("seconds", nargs="?", type=int, default=120)
  ap.add_argument("--bottom", action="store_true")
  ap.add_argument("--override", action="store_true")
  ap.add_argument("--kill", action="store_true")
  args = ap.parse_args()

  root = tk.Tk()
  root.title("kidbox-dock-test")
  width = root.winfo_screenwidth()
  y = root.winfo_screenheight() - HEIGHT if args.bottom else 0
  root.geometry(f"{width}x{HEIGHT}+0+{y}")

  if args.override:
    # No WM involvement at all. Stacking is then first-come, so lift()
    # every tick keeps it above a window mapped later.
    root.overrideredirect(True)
  else:
    # Must be set before the window is first mapped, which is why it comes
    # before mainloop() and before any update().
    root.attributes("-type", "dock")

  root.configure(bg="#1d3557")
  label = tk.Label(root, bg="#1d3557", fg="white",
                   font=("DejaVu Sans", 28, "bold"))
  label.pack(expand=True, fill="both")

  state = {"left": args.seconds}

  def tick():
    left = state["left"]
    mins, secs = divmod(left, 60)
    label.config(text=f"Time left today:  {mins:02d}:{secs:02d}")
    if left <= WARN_SECS:
      root.configure(bg="#c1121f")
      label.config(bg="#c1121f")
    print(f"{mins:02d}:{secs:02d}", flush=True)

    if args.override:
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
