# Unified Telemetry System Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace `:FPS:` and `:METRIC:` with a single `:TELEMETRY:` command — SQF collects raw counts, extension handles all formatting and routing.

**Architecture:** Move `fnc_metricsLoop.sqf` from `addons/database/` to `addons/recorder/`. Replace 11+ `callExtension` calls per tick with one `:TELEMETRY:` call using grouped sub-arrays. Extension parses positional data and routes to mission recording (FPS) and InfluxDB (all metrics).

**Tech Stack:** SQF (Arma 3), CBA macros, HEMTT build system, ocap_recorder extension DLL

---

## Problem

The current metrics system has two overlapping commands:
- `:FPS:` — sends `[captureFrameNo, diag_fps, diag_fpsmin]` to the mission recording for playback
- `:METRIC:` — sends InfluxDB-formatted data (entity counts, player network, scripts, FPS *again*, weather)

This results in:
- FPS data sent twice via different commands
- 11+ `callExtension` calls per 10-second tick
- Heavy string formatting in SQF (`joinString "::"`, InfluxDB line protocol, type annotations)
- Schema knowledge split between SQF and extension

## Decision

Replace both `:FPS:` and `:METRIC:` with a single `:TELEMETRY:` command. Since the addon and extension are always bundled, the positional array contract is safe.

**Principles:**
- SQF does counting only (it must — the extension can't access Arma objects)
- Extension handles all formatting, routing, and InfluxDB protocol assembly
- Extension decides what goes to mission recording vs InfluxDB
- One call per tick instead of 11+

## Data Structure

```sqf
[":TELEMETRY:", [
  captureFrameNo,                 // [0] frame reference
  [diag_fps, diag_fpsmin],        // [1] FPS
  [                               // [2] per-side entity counts (east, west, independent, civilian)
    [                             //     each side has [serverLocal, remote]
      [units_total, units_alive, units_dead, groups, vehicles, weaponholders],  // server-local
      [units_total, units_alive, units_dead, groups, vehicles, weaponholders]   // remote
    ],
    ...                           //     repeated for all 4 sides
  ],
  [alive, dead, groups, vehicles, weaponholders, players_alive, players_dead, players_connected],  // [3] global counts
  [spawn, execVM, exec, execFSM, pfh],  // [4] running scripts
  [fog, overcast, rain, humidity, waves, windDir, windStr, gusts, lightnings, moonIntensity, moonPhase, sunOrMoon],  // [5] weather
  [                               // [6] player network (variable length)
    [uid, name, ping, bandwidth, desync],
    ...
  ]
]] call EFUNC(extension,sendData);
```

## Extension Routing

The extension parses the positional array and routes data to two destinations:

**Mission Recording:**
- `[0]` frameNo + `[1]` FPS → write to mission timeline (replaces `:FPS:` handler)

**InfluxDB:**
- `[1]` → `server_performance/fps` (fps_avg, fps_min)
- `[2]` → 8 points: `entity_count_{server|remote}_{east|west|independent|civilian}`
- `[3]` → `server_performance/entity_count_global_all`
- `[4]` → `server_performance/running_scripts`
- `[5]` → `mission_data/weather`
- `[6]` → N × `player_performance/network` (one per player, tagged with uid/name)

Side mapping: index 0=east, 1=west, 2=independent, 3=civilian (matches SQF `forEach` order).

---

## Implementation Tasks

### Task 1: Move metricsLoop from database to recorder addon

**Files:**
- Create: `addons/recorder/fnc_metricsLoop.sqf`
- Modify: `addons/recorder/XEH_prep.sqf`
- Modify: `addons/database/XEH_prep.sqf`
- Modify: `addons/database/fnc_initDB.sqf:168`
- Delete: `addons/database/fnc_metricsLoop.sqf`

**Step 1: Add PREP(metricsLoop) to recorder's XEH_prep.sqf**

In `addons/recorder/XEH_prep.sqf`, add after the `PREP(entityMonitors);` line:

```sqf
PREP(metricsLoop);
```

**Step 2: Remove PREP(metricsLoop) from database's XEH_prep.sqf**

In `addons/database/XEH_prep.sqf`, remove line 9:

```sqf
PREP(metricsLoop);
```

**Step 3: Update fnc_initDB.sqf to call recorder's metricsLoop**

In `addons/database/fnc_initDB.sqf`, change line 168 from:

```sqf
      call FUNC(metricsLoop);
```

to:

```sqf
      call EFUNC(recorder,metricsLoop);
```

`FUNC(metricsLoop)` expands to `OCAP_database_fnc_metricsLoop` (wrong after move).
`EFUNC(recorder,metricsLoop)` expands to `OCAP_recorder_fnc_metricsLoop` (correct).

**Step 4: Create the new fnc_metricsLoop.sqf in recorder**

Create `addons/recorder/fnc_metricsLoop.sqf` with the rewritten telemetry code (see Task 2).

**Step 5: Delete the old fnc_metricsLoop.sqf from database**

Delete `addons/database/fnc_metricsLoop.sqf`.

**Step 6: Commit**

```bash
git add addons/recorder/fnc_metricsLoop.sqf addons/recorder/XEH_prep.sqf addons/database/XEH_prep.sqf addons/database/fnc_initDB.sqf
git rm addons/database/fnc_metricsLoop.sqf
git commit -m "refactor: move metricsLoop from database to recorder addon"
```

---

### Task 2: Rewrite fnc_metricsLoop.sqf with unified :TELEMETRY: call

**Files:**
- Modify: `addons/recorder/fnc_metricsLoop.sqf` (created in Task 1)

**Step 1: Write the new fnc_metricsLoop.sqf**

Replace the entire content of `addons/recorder/fnc_metricsLoop.sqf` with:

```sqf
#include "script_component.hpp"

/* ----------------------------------------------------------------------------
FILE: fnc_metricsLoop.sqf

FUNCTION: OCAP_recorder_fnc_metricsLoop

Description:
  Collects server telemetry data every 10 seconds and sends a single
  :TELEMETRY: command to the extension. The extension handles routing
  to mission recording (FPS) and InfluxDB (all metrics).

Parameters:
  None

Returns:
  None

Public:
  No

Author:
  OCAP Team
---------------------------------------------------------------------------- */

[{
  [] spawn {
    private _start = diag_tickTime;

    // Snapshot game state
    private _allUnits = allUnits;
    private _allDeadMen = allDeadMen;
    private _allGroups = allGroups;
    private _vehicles = vehicles;
    private _allPlayers = call BIS_fnc_listPlayers;

    // [2] Per-side entity counts: [east, west, independent, civilian]
    // Each side: [[serverLocal], [remote]]
    // Each locality: [units_total, units_alive, units_dead, groups, vehicles, weaponholders]
    private _sideData = [];
    {
      private _s = _x;
      private _sUnits = _allUnits select {side _x isEqualTo _s};
      private _sDead = _allDeadMen select {side _x isEqualTo _s};
      private _sGroups = _allGroups select {side _x isEqualTo _s};
      private _sVeh = _vehicles select {side _x isEqualTo _s};

      private _localUnits = _sUnits select {local _x};
      private _remoteUnits = _sUnits select {!local _x};
      private _localDead = _sDead select {local _x};
      private _remoteDead = _sDead select {!local _x};
      private _localGroups = _sGroups select {local _x};
      private _remoteGroups = _sGroups select {!local _x};
      private _localVeh = _sVeh select {local _x && !(_x isKindOf "WeaponHolderSimulated")};
      private _remoteVeh = _sVeh select {!local _x && !(_x isKindOf "WeaponHolderSimulated")};
      private _localWH = _sVeh select {local _x && _x isKindOf "WeaponHolderSimulated"};
      private _remoteWH = _sVeh select {!local _x && _x isKindOf "WeaponHolderSimulated"};

      _sideData pushBack [
        [count _localUnits, {alive _x} count _localUnits, count _localDead, count _localGroups, count _localVeh, count _localWH],
        [count _remoteUnits, {alive _x} count _remoteUnits, count _remoteDead, count _remoteGroups, count _remoteVeh, count _remoteWH]
      ];
    } forEach [east, west, independent, civilian];

    // [3] Global entity counts
    private _weaponholders = {_x isKindOf "WeaponHolderSimulated"} count _vehicles;
    private _playersAlive = {alive _x} count _allPlayers;
    private _globalCounts = [
      {alive _x} count _allUnits,
      count _allDeadMen,
      count _allGroups,
      count _vehicles - _weaponholders,
      _weaponholders,
      _playersAlive,
      count _allPlayers - _playersAlive,
      count _allPlayers
    ];

    // [4] Running scripts
    private _scripts = diag_activeScripts + [
      if (isClass(configFile >> "CfgPatches" >> "cba_main")) then {
        count CBA_common_perFrameHandlerArray
      } else {0}
    ];

    // [5] Weather
    private _weather = [
      fog, overcast, rain, humidity, waves,
      windDir, windStr, gusts, lightnings,
      moonIntensity, moonPhase date, sunOrMoon
    ];

    // [6] Player network data
    private _playerData = [];
    {
      if (_x isEqualTo []) then {continue};
      _x params ["", "", "_uid", "_name", "", "", "", "_isHC", "", "_net", "_unit"];
      if (isNull _unit || _isHC) then {continue};
      _net params ["_ping", "_bw", "_desync"];
      _playerData pushBack [_uid, _name, _ping, _bw, _desync];
    } forEach (allUsers apply {getUserInfo _x});

    // Single telemetry call — extension handles routing and formatting
    [":TELEMETRY:", [
      GVAR(captureFrameNo),
      [diag_fps, diag_fpsmin],
      _sideData,
      _globalCounts,
      _scripts,
      _weather,
      _playerData
    ]] call EFUNC(extension,sendData);

    private _dur = diag_tickTime - _start;
    if (_dur < 10) then {
      LOG(format["Telemetry logged in %1 ms", _dur]);
    } else {
      WARNING(format["Telemetry took > 10s: %1 ms", _dur]);
    };
  };
}, 10] call CBA_fnc_addPerFrameHandler;
```

Key differences from old code:
- Uses `GVAR(captureFrameNo)` instead of `EGVAR(recorder,captureFrameNo)` since we're now in the recorder component
- No `joinString "::"` anywhere
- No `"field"/"tag"/"int"/"float"` type annotations
- No `toFixed` calls (extension handles precision)
- 1 `sendData` call instead of 11+
- Pre-filters into local arrays to avoid redundant iteration

**Step 2: Build to verify syntax**

Run: `hemtt build`
Expected: Successful build with no SQF errors

**Step 3: Commit**

```bash
git add addons/recorder/fnc_metricsLoop.sqf
git commit -m "feat: unified :TELEMETRY: command replaces :FPS: and :METRIC:"
```

---

### Task 3: Extension — implement :TELEMETRY: handler (contract spec)

This task is for the extension repo (not this addon repo). Documenting here for completeness.

**Extension contract:**

The `:TELEMETRY:` handler receives one array with 7 elements at indices `[0]`–`[6]`.

**Parsing spec:**

| Index | Type | Content | Route to |
|-------|------|---------|----------|
| `[0]` | Number | `captureFrameNo` | Mission recording (with FPS from [1]) |
| `[1]` | Array[2] | `[fps_avg, fps_min]` | Mission recording + InfluxDB `server_performance/fps` |
| `[2]` | Array[4] | Per-side: `[[local_counts], [remote_counts]]` | InfluxDB `server_performance/entity_count_{server\|remote}_{side}` |
| `[3]` | Array[8] | Global counts | InfluxDB `server_performance/entity_count_global_all` |
| `[4]` | Array[5] | Script counts | InfluxDB `server_performance/running_scripts` |
| `[5]` | Array[12] | Weather values | InfluxDB `mission_data/weather` |
| `[6]` | Array[N][5] | Player network: `[uid, name, ping, bw, desync]` | InfluxDB `player_performance/network` (tagged per player) |

**Side index mapping for `[2]`:**
- `0` = east, `1` = west, `2` = independent, `3` = civilian

**Entity count positions within each `[local]`/`[remote]` sub-array:**
- `0` = units_total, `1` = units_alive, `2` = units_dead, `3` = groups_total, `4` = vehicles_total, `5` = vehicles_weaponholder

**Global counts positions `[3]`:**
- `0` = units_alive, `1` = units_dead, `2` = groups_total, `3` = vehicles_total, `4` = vehicles_weaponholder, `5` = players_alive, `6` = players_dead, `7` = players_connected

**Script counts positions `[4]`:**
- `0` = spawn, `1` = execVM, `2` = exec, `3` = execFSM, `4` = pfh

**Weather positions `[5]`:**
- `0` = fog, `1` = overcast, `2` = rain, `3` = humidity, `4` = waves, `5` = windDir, `6` = windStr, `7` = gusts, `8` = lightnings, `9` = moonIntensity, `10` = moonPhase, `11` = sunOrMoon

**Actions required in extension:**
1. Add `:TELEMETRY:` command handler
2. Write `[0]` frameNo + `[1]` FPS to mission recording (same behavior as old `:FPS:`)
3. Format `[1]`–`[6]` into InfluxDB line protocol and write (same behavior as old `:METRIC:`)
4. Remove old `:FPS:` command handler
5. Remove old `:METRIC:` command handler

---

## Comparison

| Aspect | Before | After |
|--------|--------|-------|
| Extension calls per tick | 11+ | 1 |
| String formatting in SQF | Heavy | None |
| InfluxDB protocol assembly | SQF | Extension |
| FPS routing | Separate `:FPS:` command | Extension auto-routes |
| Schema ownership | Split SQF/extension | Extension |
| Data collected | Same | Same |
