#!/usr/bin/env python3
"""Daily screen-time countdown bar, and the thing that ends the session.

Usage: kidbox-limit-bar.py <budget-seconds> <used-seconds>

Started from .xinitrc when menu.sh has decided the chosen item counts
against the daily limit (the policy -- minutes per day and which items --
is the "Daily screen-time limit" block in menu.sh). Draws a slim strip
along the bottom of the screen showing the time left today: whole minutes
until the last two, then a seconds countdown in red. At zero it says so,
waits a moment, and ends the X session the way Ctrl+Alt+Backspace does,
which drops the kid back at the menu.

The strip is a matchbox toolbar (_NET_WM_WINDOW_TYPE_TOOLBAR). Matchbox
puts toolbars along the bottom and shrinks the app to make room -- even a
fullscreen one like Chromium --kiosk, which is what makes this work: a
dock would be ignored for fullscreen clients and drawn over the page.

This is the only writer of the state file, "YYYY-MM-DD seconds-used",
which menu.sh reads. It writes every WRITE_EVERY seconds and on the way
out, through a temp file and rename so a power cut cannot leave half a
line. When the kid quits the app, X goes away under us and Tk exits the
process on the spot, so the periodic write is the real safety net: a
session can lose at most WRITE_EVERY seconds of used time.
"""

import os
import signal
import subprocess
import sys
import time
import tkinter as tk

STATE = os.path.expanduser("~/.kidbox-state/screen-time")
HEIGHT = 32
SHOW_SECONDS_BELOW = 120  # whole minutes above this, M:SS below
WRITE_EVERY = 10
GRACE = 5                 # seconds "All done" stays up before the session ends
BLUE = "#1d3557"
RED = "#c1121f"


def write_state(used):
  os.makedirs(os.path.dirname(STATE), exist_ok=True)
  tmp = STATE + ".tmp"
  with open(tmp, "w", encoding="utf-8") as f:
    f.write(f"{time.strftime('%Y-%m-%d')} {used}\n")
    f.flush()
    os.fsync(f.fileno())
  os.replace(tmp, STATE)


def wait_for_matchbox(timeout=10):
  """The toolbar type only means something once matchbox is up, and
  .xinitrc starts matchbox in the background just before us."""
  deadline = time.monotonic() + timeout
  while time.monotonic() < deadline:
    if subprocess.run(["pgrep", "-f", "matchbox-window-manager"],
                      capture_output=True).returncode == 0:
      time.sleep(1)
      return
    time.sleep(0.2)


def main():
  if len(sys.argv) != 3:
    sys.exit("usage: kidbox-limit-bar.py <budget-seconds> <used-seconds>")
  budget, used0 = int(sys.argv[1]), int(sys.argv[2])
  wait_for_matchbox()

  root = tk.Tk()
  root.title("kidbox-limit-bar")
  y = root.winfo_screenheight() - HEIGHT
  root.geometry(f"{root.winfo_screenwidth()}x{HEIGHT}+0+{y}")
  # Must be set before the window is first mapped.
  root.attributes("-type", "toolbar")
  root.configure(bg=BLUE)
  label = tk.Label(root, bg=BLUE, fg="white",
                   font=("DejaVu Sans", HEIGHT // 2, "bold"))
  label.pack(expand=True, fill="both")

  started = time.monotonic()
  state = {"used": used0, "written": used0, "done": False}

  def turn_red():
    root.configure(bg=RED)
    label.config(bg=RED)

  def end_session():
    write_state(state["used"])
    subprocess.run(["pkill", "-TERM", "Xorg"], check=False)

  def tick():
    used = state["used"] = used0 + int(time.monotonic() - started)
    left = budget - used

    if left <= 0:
      state["done"] = True
      turn_red()
      label.config(text="All done for today!")
      write_state(used)
      root.after(GRACE * 1000, end_session)
      return

    if left > SHOW_SECONDS_BELOW:
      label.config(text=f"Time left today:  {left // 60} min")
    else:
      turn_red()
      label.config(text=f"Time left today:  {left // 60}:{left % 60:02d}")

    if used - state["written"] >= WRITE_EVERY:
      write_state(used)
      state["written"] = used

    root.after(1000, tick)

  # A SIGTERM (session ending) still gets the final write below; it is
  # delivered at the next tick, since Tk's loop is C code in between.
  signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
  try:
    tick()
    root.mainloop()
  finally:
    write_state(state["used"])
  return 0


if __name__ == "__main__":
  sys.exit(main())
