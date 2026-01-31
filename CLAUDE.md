# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OCAP2 (Operation Capture and Playback v2) is an Arma 3 addon that records gameplay data during missions for web-based playback analysis. It captures unit positions, vehicles, weapons, markers, and events to facilitate tactical analysis and training.

**Language**: SQF (Arma 3 scripting language)
**Dependencies**: Arma 3 2.04+, CBA (Community Base Addons), optional ACE3 integration

## Build

Uses HEMTT for building PBO files:
```bash
hemtt build        # Development build
hemtt release      # Release build
```

The extension DLL (`ocap_recorder`) handles database export and requires separate compilation (see extension repo).

## Architecture

Modular CBA-style addon structure:

```
addons/
├── main/           # Core settings, macros, version info
├── recorder/       # Capture loop, event handlers, export
├── database/       # Database connection, metrics, real-time data streaming
└── extension/      # Extension DLL wrapper
```

Each addon follows XEH structure:
- `XEH_preInit.sqf` - CBA settings registration
- `XEH_postInit.sqf` - Post-init logic
- `XEH_prep.sqf` - Function preparation
- `config.cpp` - CfgPatches, CfgFunctions
- `script_component.hpp` - Component-specific macros

### Key Files

- **recorder/fnc_captureLoop.sqf**: Core capture loop, tracks units and vehicles per frame
- **recorder/fnc_addEventMission.sqf**: Mission event handlers setup
- **recorder/fnc_eh_firedMan.sqf**: Fired event handler with projectile tracking
- **database/fnc_initDB.sqf**: Database connection and mission context initialization
- **database/fnc_metricsLoop.sqf**: Server performance metrics collection

### Configuration

All settings use CBA Settings system (configurable in-game via addon options):
- `OCAP_enabled`: Master recording toggle
- `OCAP_settings_autoStart`: Auto-start on session begin
- `OCAP_settings_minPlayerCount`: Minimum players to start
- `OCAP_settings_frameCaptureDelay`: Capture interval in seconds
- `OCAP_settings_excludeClassFromRecord`: Classes to exclude

## Code Conventions

### CBA Macros
Functions use CBA component macros defined in `main/script_macros.hpp`:
```sqf
FUNC(name)           // Expands to OCAP_recorder_fnc_name
GVAR(name)           // Expands to OCAP_recorder_name (component variable)
EGVAR(comp,name)     // Expands to OCAP_comp_name (external component variable)
QGVAR(name)          // Quoted variable name
LOG(), INFO(), WARNING(), ERROR()  // Logging macros
```

### Includes
All functions must include at the top:
```sqf
#include "script_component.hpp"
```

### Function Documentation
```sqf
/* ----------------------------------------------------------------------------
FILE: fnc_example.sqf

FUNCTION: OCAP_recorder_fnc_example

Description:
  What this function does

Parameters:
  _param1 - description

Returns:
  description

Public:
  No

Author:
  Name
---------------------------------------------------------------------------- */
```

### ACE3 Integration
ACE3 support is optional with graceful fallback. `fnc_aceExplosives.sqf` handles placed explosives and detonation tracking.
