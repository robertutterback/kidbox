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


def find_power_button_device():
    """
    Find the input device that generates KEY_POWER events.
    Returns the device path or None if not found.
    """
    for device_path in list_devices():
        try:
            device = InputDevice(device_path)
            capabilities = device.capabilities()

            # Check if device supports KEY_POWER (ecodes.KEY_POWER = 116)
            if ecodes.EV_KEY in capabilities:
                if ecodes.KEY_POWER in capabilities[ecodes.EV_KEY]:
                    logger.info(f"Found power button device: {device.name} at {device_path}")
                    return device
        except (OSError, PermissionError) as e:
            logger.debug(f"Cannot access {device_path}: {e}")
            continue

    return None


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


def monitor_power_button(device):
    """
    Monitor power button events and handle short vs long press.
    """
    press_time = None
    last_release_time = 0

    logger.info(f"Monitoring power button on {device.path}")

    for event in device.read_loop():
        if event.type == ecodes.EV_KEY and event.code == ecodes.KEY_POWER:
            event_time = time.time()

            if event.value == 1:  # Key press
                press_time = event_time
                logger.debug(f"Power button pressed at {press_time}")

            elif event.value == 0:  # Key release
                if press_time is None:
                    logger.debug("Ignoring release without matching press")
                    continue

                # Calculate press duration
                duration = event_time - press_time
                logger.debug(f"Power button released after {duration:.2f} seconds")

                # Debounce: ignore if too soon after last release
                if event_time - last_release_time < DEBOUNCE_TIME:
                    logger.debug(f"Debouncing event (too soon after last release)")
                    press_time = None
                    continue

                last_release_time = event_time

                # Determine short vs long press
                if duration >= LONG_PRESS_THRESHOLD:
                    handle_long_press()
                elif duration >= 0.1:  # Minimum press duration to avoid bounces
                    handle_short_press()

                press_time = None


def main():
    """Main entry point."""
    logger.info("Starting kidbox power button monitor")

    # Find power button device
    device = find_power_button_device()
    if device is None:
        logger.error("Could not find power button device")
        sys.exit(1)

    # Verify power menu script exists
    if not Path(POWER_MENU_SCRIPT).exists():
        logger.error(f"Power menu script not found at {POWER_MENU_SCRIPT}")
        sys.exit(1)

    # Monitor power button events
    try:
        monitor_power_button(device)
    except KeyboardInterrupt:
        logger.info("Stopped by user")
    except Exception as e:
        logger.error(f"Error monitoring power button: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
