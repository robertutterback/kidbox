# Kidbox Project - Claude Context

## Project Overview

Kidbox is a locked-down, retro-style kid computer setup designed for Raspberry Pi. It provides a simple, educational computing environment for children.

## Project Structure

```
kidbox/
├── bin/              # Executable scripts (menu.sh, launchers)
├── config/           # Configuration files
├── content/          # Content files (clock, timer, stopwatch apps)
├── doc/              # Documentation and instruction booklets
└── install.sh        # Main installation script
```

## Key Technologies

- **Shell Scripts**: Menu system and application launchers
- **X Window System**: Minimal X sessions for graphical apps
- **HTML/CSS/JS**: Clock, timer, and stopwatch applications
- **LaTeX**: Instruction booklet (doc/kidbook.tex)

## Activities Available

1. **Logo**: UCBLogo programming environment
2. **BASIC**: PC-BASIC (GW-BASIC-like)
3. **Typing**: Leafpad text editor
4. **Drawing**: Tux Paint
5. **Clock**: HTML/CSS/JS analog + digital clock
6. **Timer**: Visual countdown with optional sounds
7. **Stopwatch**: Count-up timer
8. **Book**: Instruction manual viewer

## Important Considerations

### Target Platform
- Designed for **Raspberry Pi**
- Console-based boot with auto-login
- Minimal X sessions launched on-demand

### Design Philosophy
- **Intentionally simple and explicit**
- Educational: encourages understanding how the computer works
- Locked-down: limited to specific approved activities
- Retro style: console-first interface

### Installation Flow
1. Install runs as root with KID_USER environment variable
2. Sets up files in /home/<kiduser>/
3. Console auto-login must be configured manually
4. Updates handled via git pull + re-run install.sh

## Common Tasks

### Testing Changes
- Test scripts on actual Raspberry Pi when possible
- Menu system: `/home/<kiduser>/bin/menu.sh`
- X session config: `/home/<kiduser>/.xinitrc`

### Building Documentation
- LaTeX compilation should be done on development machine
- Run `make` in doc/ directory

### Sound Files
- Optional timer.mp3 (background music)
- Optional alarm.mp3 (alarm sound)
- Licensed from Mixkit with free license

## Code Style

- Shell scripts: Keep simple and readable for educational purposes
- HTML/CSS/JS: Minimal dependencies, works in Chromium kiosk mode
- Configuration: Use environment variables (e.g., KID_USER)

## Notes for AI Assistance

- Prioritize simplicity over sophistication
- Keep in mind the target audience is children
- Changes should maintain the educational, retro character
- Test considerations for Raspberry Pi resource constraints
- Installation script must be idempotent (safe to re-run)
