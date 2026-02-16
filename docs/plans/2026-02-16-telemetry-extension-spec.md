# Extension Spec: `:TELEMETRY:` Command

## Overview

The `:TELEMETRY:` command replaces both `:FPS:` and `:METRIC:`. It is called once every 10 seconds from the SQF addon via `callExtension`. The extension is responsible for:

1. Writing FPS data to the mission recording (previously done by `:FPS:`)
2. Formatting all metrics into InfluxDB line protocol and writing them (previously done by `:METRIC:`)
3. The old `:FPS:` and `:METRIC:` handlers should be removed

## Wire Format

Arma's `callExtension` serializes each top-level argument to a string. The extension receives:

```
function: ":TELEMETRY:"
args: [
  "0",                                          // args[0] - captureFrameNo (string of integer)
  "[43.3604,4.36681]",                          // args[1] - FPS array (string to parse)
  "[[[1,1,0,1,0,0],[0,0,0,0,0,0]],...]",       // args[2] - per-side entity counts (string to parse)
  "[22,12,15,28,0,1,0,1]",                      // args[3] - global entity counts (string to parse)
  "[28,4,0,4,2]",                               // args[4] - running scripts (string to parse)
  "[0.2,0.25,0,0,0.1,0,0.25,0.315,...]",       // args[5] - weather (string to parse)
  "[[\"76561198...\",\"name\",100,28,0],...]"   // args[6] - player network data (string to parse)
]
```

Each `args[N]` is a string that must be parsed as a JSON-like array. Arma uses the same bracket/comma syntax as JSON for arrays, strings are double-quoted, numbers are bare.

## args[0] — Frame Number

| Type | Description |
|------|-------------|
| Integer (as string) | Current recording frame number (`OCAP_recorder_captureFrameNo`) |

This is the same frame counter used by the capture loop. Increments by 1 per capture tick (every `frameCaptureDelay` seconds, typically 0.2s). Used to correlate FPS with the playback timeline.

**Example:** `"134"`

## args[1] — Server FPS

Parse as: `[float, float]`

| Index | Type | Description | Arma source |
|-------|------|-------------|-------------|
| 0 | float | Average FPS | `diag_fps` |
| 1 | float | Minimum FPS | `diag_fpsmin` |

**Example:** `"[43.3604,4.36681]"`

### Routing

**Mission recording:** Write `args[0]` (frameNo) + `args[1][0]` (fps) + `args[1][1]` (fpsMin) to the mission timeline. This replaces the old `:FPS:` handler which received `[captureFrameNo, diag_fps, diag_fpsmin]`.

**InfluxDB:** Write as measurement `server_performance`, point `fps`:
- Field `fps_avg` (float) = `args[1][0]`
- Field `fps_min` (float) = `args[1][1]`

## args[2] — Per-Side Entity Counts

Parse as: `Array[4]` — one entry per side, in this fixed order:

| Index | Side |
|-------|------|
| 0 | East (OPFOR) |
| 1 | West (BLUFOR) |
| 2 | Independent (INDFOR) |
| 3 | Civilian |

Each side is an array of 2 sub-arrays: `[server_local_counts, remote_counts]`

Each counts sub-array has 6 integers:

| Index | Field | Type | Description |
|-------|-------|------|-------------|
| 0 | units_total | int | All units on this side with this locality (from `allUnits`) |
| 1 | units_alive | int | Alive units only (filtered with `alive`) |
| 2 | units_dead | int | Dead units (from `allDeadMen`) |
| 3 | groups_total | int | Active groups |
| 4 | vehicles_total | int | Vehicles excluding weapon holders |
| 5 | vehicles_weaponholder | int | Weapon holder objects (dropped weapons/items on ground) |

**Note on units_total vs units_alive:** In Arma 3, `allUnits` typically only contains living units, so these values are usually equal. They may diverge with unconscious units (e.g., ACE medical). Both are provided for completeness.

**Example:** `"[[[33,33,0,10,0,0],[0,0,0,0,0,0]],[[6,6,0,8,1,0],[0,0,0,0,0,0]],[[5,5,0,6,0,0],[0,0,0,0,0,0]],[[4,4,19,0,23,22],[0,0,0,0,0,0]]]"`

Decoded: East has 33 server-local units alive, 0 remote. West has 6 local, 0 remote. Etc.

### Routing

**InfluxDB:** Write 8 points (4 sides × 2 localities):

For each side index `i` (0–3) with side name from `["east", "west", "independent", "civilian"]`:

- Measurement: `server_performance`
- Point: `entity_count_server_{sideName}` for `args[2][i][0]` (server-local)
- Point: `entity_count_remote_{sideName}` for `args[2][i][1]` (remote)
- Tag: `side` = sideName
- Fields: `units_total` (int), `units_alive` (int), `units_dead` (int), `groups_total` (int), `vehicles_total` (int), `vehicles_weaponholder` (int)

## args[3] — Global Entity Counts

Parse as: `Array[8]` of integers/floats

| Index | Field | Type | Description |
|-------|-------|------|-------------|
| 0 | units_alive | int | Living units across all sides (`{alive _x} count allUnits`) |
| 1 | units_dead | int | Dead units across all sides (`count allDeadMen`) |
| 2 | groups_total | int | All active groups |
| 3 | vehicles_total | int | All vehicles excluding weapon holders |
| 4 | vehicles_weaponholder | int | All weapon holder objects |
| 5 | players_alive | int | Connected players that are alive |
| 6 | players_dead | int | Connected players that are dead |
| 7 | players_connected | int | Total connected players (alive + dead) |

**Example:** `"[49,17,24,28,22,1,0,1]"`

### Routing

**InfluxDB:** Write as measurement `server_performance`, point `entity_count_global_all`:
- Fields: all 8 values as integers with the field names listed above

Also write measurement `server_performance`, point `player_count`:
- Field: `players_connected` (int) = `args[3][7]`

## args[4] — Running Scripts

Parse as: `Array[5]` of integers

| Index | Field | Type | Description |
|-------|-------|------|-------------|
| 0 | spawn | int | Active `spawn` script instances |
| 1 | execVM | int | Active `execVM` script instances |
| 2 | exec | int | Active `exec` script instances |
| 3 | execFSM | int | Active `execFSM` (FSM) instances |
| 4 | pfh | int | CBA per-frame handlers registered (0 if CBA not loaded) |

**Note:** Indices 0–3 come from Arma's `diag_activeScripts` command. Index 4 is `count CBA_common_perFrameHandlerArray`.

**Example:** `"[28,4,0,4,2]"`

### Routing

**InfluxDB:** Write as measurement `server_performance`, point `running_scripts`:
- Fields: all 5 values as integers with the field names listed above

## args[5] — Weather

Parse as: `Array[12]` of floats

| Index | Field | Type | Range | Description |
|-------|-------|------|-------|-------------|
| 0 | fog | float | 0–1 | Fog intensity |
| 1 | overcast | float | 0–1 | Cloud cover |
| 2 | rain | float | 0–1 | Rain intensity |
| 3 | humidity | float | 0–1 | Air humidity |
| 4 | waves | float | 0–1 | Wave height |
| 5 | windDir | float | 0–360 | Wind direction in degrees |
| 6 | windStr | float | 0–1 | Wind strength |
| 7 | gusts | float | 0–1 | Gust intensity |
| 8 | lightnings | float | 0–1 | Lightning intensity |
| 9 | moonIntensity | float | 0–1 | Moon brightness |
| 10 | moonPhase | float | 0–1 | Moon phase (0=new, 0.5=full, 1=new) |
| 11 | sunOrMoon | float | 0 or 1 | 0 = nighttime (moon), 1 = daytime (sun) |

**Example:** `"[0.2,0.25,0,0,0.1,160.864,0.25,0.175,0.003153,0.441581,0.421672,1]"`

### Routing

**InfluxDB:** Write as measurement `mission_data`, point `weather`:
- Fields: all 12 values as floats with the field names listed above

## args[6] — Player Network Data

Parse as: `Array[N]` — variable length, one entry per connected human player (excluding headless clients).

Each entry is an array of 5 elements:

| Index | Field | Type | Description |
|-------|-------|------|-------------|
| 0 | playerUID | string | Steam UID (e.g., `"76561198000074241"`) |
| 1 | playerName | string | Profile name |
| 2 | avgPing | float | Average ping in ms |
| 3 | avgBandwidth | float | Average bandwidth |
| 4 | desync | float | Desync value |

**Example:** `"[[\\"76561198000074241\\",\\"info\\",100,28,0]]"` (one player)

**Empty state:** If no players are connected, this is `"[]"`.

### Routing

**InfluxDB:** Write N points, one per player, as measurement `player_performance`, point `network`:
- Tag: `playerUID` = entry[0]
- Tag: `playerName` = entry[1]
- Field: `avgPing` (float) = entry[2]
- Field: `avgBandwidth` (float) = entry[3]
- Field: `desync` (float) = entry[4]

## Complete Example

A real call from the RPT log:

```
command: ":TELEMETRY:"
args[0]: "0"
args[1]: "[43.3604,4.36681]"
args[2]: "[[[1,1,0,1,0,0],[0,0,0,0,0,0]],[[10,10,0,8,0,0],[0,0,0,0,0,0]],[[6,6,0,6,0,0],[0,0,0,0,0,0]],[[5,5,12,0,24,0],[0,0,0,0,0,0]]]"
args[3]: "[22,12,15,28,0,1,0,1]"
args[4]: "[28,4,0,4,2]"
args[5]: "[0.2,0.25,0,0,0.1,0,0.25,0.315,0,0.423059,0.421672,1]"
args[6]: "[[\\"76561198000074241\\",\\"info\\",100,28,0]]"
```

This should produce:

**Mission recording:**
- Frame 0: fps=43.36, fpsMin=4.37

**InfluxDB writes (13 points):**
1. `server_performance,point=fps fps_avg=43.3604,fps_min=4.36681`
2. `server_performance,point=entity_count_server_east,side=east units_total=1i,units_alive=1i,units_dead=0i,groups_total=1i,vehicles_total=0i,vehicles_weaponholder=0i`
3. `server_performance,point=entity_count_remote_east,side=east units_total=0i,units_alive=0i,units_dead=0i,groups_total=0i,vehicles_total=0i,vehicles_weaponholder=0i`
4. `server_performance,point=entity_count_server_west,side=west ...`
5. `server_performance,point=entity_count_remote_west,side=west ...`
6. `server_performance,point=entity_count_server_independent,side=independent ...`
7. `server_performance,point=entity_count_remote_independent,side=independent ...`
8. `server_performance,point=entity_count_server_civilian,side=civilian ...`
9. `server_performance,point=entity_count_remote_civilian,side=civilian ...`
10. `server_performance,point=entity_count_global_all units_alive=22i,units_dead=12i,groups_total=15i,vehicles_total=28i,vehicles_weaponholder=0i,players_alive=1i,players_dead=0i,players_connected=1i`
11. `server_performance,point=player_count players_connected=1i`
12. `server_performance,point=running_scripts spawn=28i,execVM=4i,exec=0i,execFSM=4i,pfh=2i`
13. `mission_data,point=weather fog=0.2,overcast=0.25,rain=0,humidity=0,waves=0.1,windDir=0,windStr=0.25,gusts=0.315,lightnings=0,moonIntensity=0.423059,moonPhase=0.421672,sunOrMoon=1`

**Plus per-player:**
14. `player_performance,point=network,playerUID=76561198000074241,playerName=info avgPing=100,avgBandwidth=28,desync=0`

## Migration Checklist

- [ ] Implement `:TELEMETRY:` command handler with parsing and routing as described above
- [ ] Verify mission recording receives FPS data (frame correlation with playback)
- [ ] Verify all InfluxDB measurements populate with correct field names and types
- [ ] Remove old `:FPS:` command handler
- [ ] Remove old `:METRIC:` command handler
- [ ] Handle edge case: `args[6]` is `"[]"` when no players connected (skip player writes)

## Response

Return `["ok", "queued"]` on success (same as current behavior for async commands).
