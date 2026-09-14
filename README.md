# OCAP Addon

Arma 3 addon for Operation Capture and Playback (OCAP). Records gameplay data during missions for web-based playback analysis.

> **Note:** For general OCAP information, documentation, and issue tracking, see the main repository: https://github.com/OCAP2/OCAP

## Requirements

- Arma 3 2.10+
- [CBA_A3](https://steamcommunity.com/workshop/filedetails/?id=450814997)
- [OCAP Recorder Extension](https://github.com/OCAP2/extension) (for database export)
- Optional: ACE3 for enhanced medical state tracking

## Installation

Download the latest release from [GitHub Releases](https://github.com/OCAP2/addon/releases) and place the `@ocap` folder in your Arma 3 directory.

## Building from Source

Requires [HEMTT](https://github.com/BrettMayson/HEMTT):

```bash
hemtt build        # Development build
hemtt release      # Release build with signed PBOs
```

## Configuration

All settings are configurable in-game via CBA Settings (Options > Addon Options > OCAP).
Player Detail Tracking names and tooltips are stringtable entries
(`addons/recorder/stringtable.xml`) so they follow the game language.

Key settings:
- **Recording Enabled** - Master toggle
- **Auto Start Recording** - Start recording when minimum player count is reached
- **Minimum Player Count** - Players required for auto-start
- **Frame Capture Delay** - Interval between position captures (seconds)

### Player Detail Tracking

Optional per-player snapshots (gear, medical, stamina, radios) sampled on each
client and stored as extra events. AI is not sampled. Defaults, intervals and
the `force` block live in [docs/player-detail-tracking.md](docs/player-detail-tracking.md).

Pinned production values:

```sqf
force OCAP_settings_trackPlayerInventory = true;
force OCAP_settings_playerInventoryInterval = 120;
force OCAP_settings_trackPlayerInventoryOnDeath = true;
force OCAP_settings_trackPlayerMedical = true;
force OCAP_settings_playerMedicalInterval = 60;
force OCAP_settings_playerMedicalCriticalInterval = 10;
force OCAP_settings_trackPlayerStamina = true;
force OCAP_settings_playerStaminaInterval = 30;
force OCAP_settings_trackPlayerRadio = true;
force OCAP_settings_playerRadioInterval = 120;
force OCAP_settings_trackPlayerSnapshotDiffs = true;
force OCAP_settings_radioShortRangeMeters = 5000;
force OCAP_settings_radioLongRangeMeters = 20000;
force OCAP_settings_trackServerFps = true;
force OCAP_settings_trackWeather = true;
```

### Server Performance

`OCAP_settings_trackServerFps` defaults to `true`. It records server `diag_fps`
at recording start and every 10 seconds for the web playback Stats panel.

### Weather

`OCAP_settings_trackWeather` defaults to `true`. It records vanilla weather
(overcast, rain, fog, wind, humidity, moon phase) at recording start and every
60 seconds. When ACE Weather is loaded and `ace_weather_enabled` is on, ACE air
temperature and humidity replace the vanilla readings. The Stats panel shows
the sample at the playhead.

## License

GNU General Public License v3.0
