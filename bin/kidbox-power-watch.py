#!/usr/bin/env python3
"""
kidbox-power-watch.py

Monitors the physical power button and distinguishes between short and long presses:
- Short press (< 2.0 seconds): Launch power menu (kidbox-power-menu.sh)
- Long press (>= 2.0 seconds): Immediate poweroff (emergency override)

This script runs as a systemd service (kidbox-power-watch.service) started at boot.
It requires python3-evdev package.

The script:
1. Finds the input device that generates KEY_POWER events
2. Monitors that device for key press/release events
3. Tracks timing to distinguish short vs long press
4. Debounces repeated events
"""

import sys
import time
import select
import subprocess
import logging
from pathlib import Path

try:
    from evdev import InputDevice, ecodes, list_devices
except ImportError:
    print("ERROR: python3-evdev not installed. Install with: apt-get install python3-evdev", file=sys.stderr)
    sys.exit(1)

# Configuration
LONG_PRESS_THRESHOLD = 2.0  # seconds
POWER_MENU_SCRIPT = "/usr/local/bin/kidbox-power-menu.sh"
DEBOUNCE_TIME = 0.5  # seconds - ignore events within this time of last release

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


def find_power_button_devices():
    """
    Find all input devices that advertise KEY_POWER capability.
    Many devices advertise KEY_POWER without actually generating it,
    so we monitor all of them and react to whichever fires.
    """
    devices = []
    for device_path in list_devices():
        try:
            device = InputDevice(device_path)
            capabilities = device.capabilities()
            if ecodes.EV_KEY in capabilities:
                if ecodes.KEY_POWER in capabilities[ecodes.EV_KEY]:
                    logger.info(f"Found KEY_POWER device: {device.name} at {device_path}")
                    devices.append(device)
        except (OSError, PermissionError) as e:
            logger.debug(f"Cannot access {device_path}: {e}")
            continue
    return devices


def handle_short_press():
    """Handle short power button press - show menu."""
    logger.info("Short press detected - showing power menu")
    try:
        # Run power menu script
        subprocess.run([POWER_MENU_SCRIPT], check=False)
    except Exception as e:
        logger.error(f"Failed to launch power menu: {e}")


def handle_long_press():
    """Handle long power button press - immediate poweroff."""
    logger.warning("Long press detected - initiating immediate poweroff")
    try:
        subprocess.run(["/usr/bin/systemctl", "poweroff"], check=False)
    except Exception as e:
        logger.error(f"Failed to poweroff: {e}")


def monitor_power_button(devices):
    """
    Monitor all candidate devices for KEY_POWER events using select().
    """
    press_time = None
    last_release_time = 0
    device_map = {dev.fd: dev for dev in devices}

    logger.info(f"Monitoring {len(devices)} device(s) for power button events")

    while True:
        r, _, _ = select.select(device_map.keys(), [], [])
        for fd in r:
            for event in device_map[fd].read():
                if event.type != ecodes.EV_KEY or event.code != ecodes.KEY_POWER:
                    continue

                event_time = time.time()

                if event.value == 1:  # Key press
                    press_time = event_time
                    logger.info(f"Power button pressed on {device_map[fd].name}")

                elif event.value == 0:  # Key release
                    if press_time is None:
                        continue

                    duration = event_time - press_time

                    # Debounce: ignore if too soon after last release
                    if event_time - last_release_time < DEBOUNCE_TIME:
                        press_time = None
                        continue

                    last_release_time = event_time

                    # Determine short vs long press
                    if duration >= LONG_PRESS_THRESHOLD:
                        handle_long_press()
                    elif duration >= 0.1:
                        handle_short_press()

                    press_time = None


def main():
    """Main entry point."""
    logger.info("Starting kidbox power button monitor")

    # Find all devices that advertise KEY_POWER
    devices = find_power_button_devices()
    if not devices:
        logger.error("Could not find any device with KEY_POWER capability")
        sys.exit(1)

    # Verify power menu script exists
    if not Path(POWER_MENU_SCRIPT).exists():
        logger.error(f"Power menu script not found at {POWER_MENU_SCRIPT}")
        sys.exit(1)

    # Monitor power button events
    try:
        monitor_power_button(devices)
    except KeyboardInterrupt:
        logger.info("Stopped by user")
    except Exception as e:
        logger.error(f"Error monitoring power button: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
