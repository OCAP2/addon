# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OCAP2 (Operation Capture and Playback v2) is an Arma 3 addon that records gameplay data during missions for web-based playback analysis. It captures unit positions, vehicles, weapons, markers, and events to facilitate tactical analysis and training.

**Language**: SQF (Arma 3 scripting language)
**Dependencies**: Arma 3 2.04+, CBA (Community Base Addons), optional ACE3 integration

## Development

There is no build system for SQF development. Edit `.sqf` files directly and pack the addon as a `.pbo` file using Arma 3 tools (Addon Builder or similar).

The extension DLL (`OcapReplaySaver2`) handles performance-critical data export and requires separate compilation.

## Architecture

```
addons/@ocap/addons/ocap/
├── config.cpp              # CfgPatches, CfgFunctions, CfgRemoteExec definitions
├── script_macros.hpp       # LOG, DEBUG, BOOL macros and ARR2-ARR6 array helpers
└── functions/              # All SQF functions
```

### Key Files

- **fn_startCaptureLoop.sqf**: Core capture loop (runs ~10Hz), tracks all units and vehicles per frame
- **fn_extension.sqf**: Wrapper for native DLL extension calls
- **fn_addEventHandlers.sqf**: Sets up fired/hit/killed/connected event handlers
- **fn_getUnitType.sqf**: Classifies unit roles (medic, engineer, crew, etc.)

### Configuration

User settings are in `userconfig/ocap/config.hpp`. Key options:
- `ocap_autoStart`: Auto-start recording on session begin
- `ocap_minPlayerCount`: Minimum players required to start
- `ocap_frameCaptureDelay`: Capture interval in seconds
- `ocap_excludeClassFromRecord`: Classes to exclude from recording

## Code Conventions

### Function Documentation
Every function has a JSDoc-style header block:
```sqf
/*
 * Script: fn_example.sqf
 * Description: What this function does
 * Parameters:
 *   _param1 - description
 * Returns: description
 * Examples: (examples)
 * Public: Yes/No
 * Author: Name
 */
```

### Includes
All functions must include at the top:
```sqf
#include "\userconfig\ocap\config.hpp"
#include "script_macros.hpp"
```

### Naming
- Global functions: `ocap_fnc_<name>` (defined in config.cpp)
- Global variables: `ocap_<name>`
- Macros: `LOG("message")`, `DEBUG("message")`, `BOOL(value)`

### ACE3 Integration
ACE3 support is optional with graceful fallback. The `fn_trackAce*.sqf` functions handle:
- Explosive lifecycle tracking (throw-to-detonation)
- Placed charges and mines
- Remote detonation events
- Thrown grenades with 3D position tracking
