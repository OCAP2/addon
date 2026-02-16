# Unified Telemetry System Design

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

## SQF Changes

**File:** `addons/recorder/fnc_metricsLoop.sqf` (moved from `addons/database/`)

- Remove the standalone `:FPS:` PFH
- Remove all `joinString "::"` formatting
- Remove all `"field"/"tag"/"int"/"float"` type annotations
- Collect the same data, send as one structured array
- Keep the `spawn` wrapper for async execution
- Keep the timing/warning check

## Extension Changes

- Remove `:FPS:` command handler
- Remove `:METRIC:` command handler
- Add `:TELEMETRY:` command handler that:
  1. Parses positional sub-arrays
  2. Writes FPS to mission recording
  3. Formats each group into InfluxDB line protocol
  4. Batch-writes to InfluxDB

## Files Affected

| File | Change |
|------|--------|
| `addons/recorder/fnc_metricsLoop.sqf` | Rewrite (move from database, single `:TELEMETRY:` call) |
| `addons/database/fnc_metricsLoop.sqf` | Remove (moved to recorder) |
| `addons/database/fnc_initDB.sqf` | Update call to metricsLoop (new location) |
| Extension `:FPS:` handler | Remove |
| Extension `:METRIC:` handler | Remove |
| Extension `:TELEMETRY:` handler | Add |

## Comparison

| Aspect | Before | After |
|--------|--------|-------|
| Extension calls per tick | 11+ | 1 |
| String formatting in SQF | Heavy | None |
| InfluxDB protocol assembly | SQF | Extension |
| FPS routing | Separate `:FPS:` command | Extension auto-routes |
| Schema ownership | Split SQF/extension | Extension |
| Data collected | Same | Same |
