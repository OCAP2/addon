# Separate capturedFlag from :EVENT:SECTOR: Design

## Problem

`capturedFlag` and `captured`/`contested` are fundamentally different event types with incompatible field semantics, but both are routed through `:EVENT:SECTOR:`:

- **captured/contested** (sector-centric): `[objectType, unitName, side, position]` — a sector changes ownership
- **capturedFlag** (player-centric): `[unitName, unitSide, flagSide]` — a player captures a flag

When capturedFlag goes through `:EVENT:SECTOR:`, fields get misinterpreted:
- Player name → stored as objectType
- Player's side ("WEST") → stored as unitName
- Flag's side → stored as side

Result: web shows "Sector WEST captured (EAST)" instead of "PlayerA captured the flag".

## Decision

- `capturedFlag` is deprecated and no longer actively used by mission makers
- Remove it from `:EVENT:SECTOR:` routing; let it fall through to `:EVENT:GENERAL:`
- Keep backward compatibility for old JSON recordings that contain capturedFlag events

## Data Flow

### v1 JSON export (extension memory backend)

**captured/contested** (new extension):
```json
[frameNum, "captured", ["sector", "Alpha", "WEST", [100, 200, 0]]]
```

**capturedFlag** (old C++ extension recordings):
```json
[frameNum, "capturedFlag", ["PlayerA", "WEST", "EAST"]]
```

### Web import path

v1 JSON → `parser_v1.go` (joins string parts, extracts position) → protobuf storage → `protobufDecoder.ts`

For captured: `message = "sector,Alpha,WEST"`, `posX = 100`, `posY = 200`
For capturedFlag: `message = "PlayerA,WEST,EAST"`, no position

### Protobuf decoder field mapping

**captured/contested** — message = `"objectType,unitName,side"`:
- `parts[0]` = objectType
- `parts[1]` = unitName
- `parts[2]` = side

**capturedFlag** — message = `"unitName,unitSide,flagSide"`:
- `parts[0]` = unitName
- objectType = "flag" (hardcoded)

These have different field orders and must be separate decoder cases.

## Changes

### Addon (`fnc_handleCustomEvent.sqf`)
- Remove `case "capturedFlag"` from sector switch block
- Falls through to `default` → `:EVENT:GENERAL:`
- Update header comment

### Extension
- Remove `capturedFlag` references from comments in `events.go`, `parse_events.go`, `builder.go`
- Remove `capturedFlag` test case from `parse_events_test.go`
- No structural changes

### Web
- `protobufDecoder.ts`: Separate `capturedFlag` into own case; remove `knownObjectTypes` heuristic from captured/contested; fix comments
- `jsonDecoder.ts`: No changes (already has separate `case "capturedFlag"`)
- `parser_v1.go`: No changes
