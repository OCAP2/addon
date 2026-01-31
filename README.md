# OCAP Addon

Arma 3 addon for Operation Capture and Playback (OCAP). Records gameplay data during missions for web-based playback analysis.

> **Note:** For general OCAP information, documentation, and issue tracking, see the main repository: https://github.com/OCAP2/OCAP

## Requirements

- Arma 3 2.10+
- [CBA_A3](https://steamcommunity.com/workshop/filedetails/?id=450814997)
- [OCAP Recorder Extension](https://github.com/OCAP2/extension) (for database export)
- Optional: ACE3 for enhanced medical state tracking

## Installation

Subscribe via Steam Workshop or download the latest release and place the `@OCAP` folder in your Arma 3 directory.

## Building from Source

Requires [HEMTT](https://github.com/BrettMayson/HEMTT):

```bash
hemtt build        # Development build
hemtt release      # Release build with signed PBOs
```

## Configuration

All settings are configurable in-game via CBA Settings (Options > Addon Options > OCAP).

Key settings:
- **Recording Enabled** - Master toggle
- **Auto Start Recording** - Start recording when minimum player count is reached
- **Minimum Player Count** - Players required for auto-start
- **Frame Capture Delay** - Interval between position captures (seconds)

## License

GNU General Public License v3.0
