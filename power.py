from evdev import InputDevice, ecodes, list_devices
for d in list_devices():
  dev = InputDevice(d)
  caps = dev.capabilities().get(ecodes.EV_KEY, [])
  has_power = ecodes.KEY_POWER in caps
  print(f'{d}: {dev.name} (KEY_POWER={has_power})')
