#!/usr/bin/env python3
"""Ctrl+Alt+Backspace and the volume keys for programs that take over the
keyboard.

Usage: kidbox-quit-watch.py <pid>

Everywhere else, Ctrl+Alt+Backspace ends the session through xbindkeys. A
fullscreen DOSBox grabs the keyboard, so X never hands those keys to
xbindkeys. This watches the keyboards directly through evdev, underneath X
where no grab reaches, and when it sees Ctrl+Alt+Backspace it ends <pid>
(DOSBox). dos.sh then exits, which ends the X session as usual.

It handles the volume keys the same way, since xbindkeys cannot: the
keyboard's own volume keys, or Ctrl+Alt+Up / Down and Ctrl+Alt+M to mute,
run kidbox-volume.sh, as config/xbindkeysrc does everywhere else.

It only reads the devices -- it does not grab them -- so the keys still
reach DOSBox as well. It exits on its own once <pid> is gone. Reading
/dev/input needs the "input" group, which install.sh gives the kid user.
"""

import os
import select
import signal
import subprocess
import sys

from evdev import InputDevice, ecodes, list_devices

CTRL = {ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL}
ALT = {ecodes.KEY_LEFTALT, ecodes.KEY_RIGHTALT}

VOLUME = os.path.expanduser("~/bin/kidbox-volume.sh")
# Keys that change the volume on their own.
MEDIA_KEYS = {
  ecodes.KEY_VOLUMEUP: "up",
  ecodes.KEY_VOLUMEDOWN: "down",
  ecodes.KEY_MUTE: "mute",
}
# Keys that change the volume with Ctrl+Alt held.
CHORD_KEYS = {
  ecodes.KEY_UP: "up",
  ecodes.KEY_DOWN: "down",
  ecodes.KEY_M: "mute",
}


def volume(action):
  try:
    subprocess.call([VOLUME, action])
  except OSError:
    pass


def keyboards():
  found = []
  for path in list_devices():
    try:
      dev = InputDevice(path)
      keys = dev.capabilities().get(ecodes.EV_KEY, [])
      # Volume keys are often on a device of their own, without the
      # ordinary keys.
      if ecodes.KEY_BACKSPACE in keys or ecodes.KEY_VOLUMEUP in keys:
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
        # 1 is a key press, 2 a repeat while it is held.
        if ev.type != ecodes.EV_KEY or ev.value not in (1, 2):
          continue
        if ev.code in MEDIA_KEYS:
          # Mute toggles, so it must not repeat.
          if ev.value == 1 or MEDIA_KEYS[ev.code] != "mute":
            volume(MEDIA_KEYS[ev.code])
          continue
        if ev.code != ecodes.KEY_BACKSPACE and ev.code not in CHORD_KEYS:
          continue
        held = set(dev.active_keys())
        if not (held & CTRL and held & ALT):
          continue
        if ev.code == ecodes.KEY_BACKSPACE:
          if ev.value == 1:
            os.kill(pid, signal.SIGTERM)
            return 0
        elif ev.value == 1 or CHORD_KEYS[ev.code] != "mute":
          volume(CHORD_KEYS[ev.code])
    if not devices:
      sys.exit("kidbox-quit-watch: lost every keyboard")
  return 0


if __name__ == "__main__":
  sys.exit(main())
