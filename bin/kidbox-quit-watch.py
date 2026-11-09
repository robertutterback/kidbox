#!/usr/bin/env python3
"""Ctrl+Alt+Backspace for programs that take over the keyboard.

Usage: kidbox-quit-watch.py <pid>

Everywhere else, Ctrl+Alt+Backspace ends the session through xbindkeys. A
fullscreen DOSBox grabs the keyboard, so X never hands those keys to
xbindkeys. This watches the keyboards directly through evdev, underneath X
where no grab reaches, and when it sees Ctrl+Alt+Backspace it ends <pid>
(DOSBox). dos.sh then exits, which ends the X session as usual.

It only reads the devices -- it does not grab them -- so the keys still
reach DOSBox as well. It exits on its own once <pid> is gone. Reading
/dev/input needs the "input" group, which install.sh gives the kid user.
"""

import os
import select
import signal
import sys

from evdev import InputDevice, ecodes, list_devices

CTRL = {ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL}
ALT = {ecodes.KEY_LEFTALT, ecodes.KEY_RIGHTALT}


def keyboards():
  found = []
  for path in list_devices():
    try:
      dev = InputDevice(path)
      keys = dev.capabilities().get(ecodes.EV_KEY, [])
      if ecodes.KEY_BACKSPACE in keys:
        found.append(dev)
      else:
        dev.close()
    except OSError:
      continue
  return found


def alive(pid):
  try:
    os.kill(pid, 0)
    return True
  except ProcessLookupError:
    return False


def main():
  if len(sys.argv) != 2:
    sys.exit("usage: kidbox-quit-watch.py <pid>")
  pid = int(sys.argv[1])

  devices = {dev.fd: dev for dev in keyboards()}
  if not devices:
    sys.exit("kidbox-quit-watch: no readable keyboard (is the user in the"
             " input group?)")

  while alive(pid):
    ready, _, _ = select.select(list(devices), [], [], 1.0)
    for fd in ready:
      dev = devices[fd]
      try:
        events = list(dev.read())
      except OSError:
        # Keyboard unplugged: stop watching it, keep the others.
        del devices[fd]
        continue
      for ev in events:
        if (ev.type == ecodes.EV_KEY and ev.code == ecodes.KEY_BACKSPACE
            and ev.value == 1):
          held = set(dev.active_keys())
          if held & CTRL and held & ALT:
            os.kill(pid, signal.SIGTERM)
            return 0
    if not devices:
      sys.exit("kidbox-quit-watch: lost every keyboard")
  return 0


if __name__ == "__main__":
  sys.exit(main())
