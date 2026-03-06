# Script-Side Focus Range

## Problem

OCAP2 records entire missions including prep phases, briefings, and downtime. The web UI already supports a focus range (focusStart/focusEnd in frames) to highlight the interesting portion, but it can only be set after upload via the admin interface. Mission makers want to define this range from SQF during the mission.

## Design

### Addon (SQF)

Two new CBA server events:

- `OCAP_setFocusStart` — optional param `[frameNumber]`, defaults to current `GVAR(captureFrameNo)`
- `OCAP_setFocusEnd` — same pattern

Each event sends a command to the extension immediately:
- `:MISSION:FOCUS_START:<frame>`
- `:MISSION:FOCUS_END:<frame>`

No SQF-side storage — the extension is the source of truth.

### Extension (Go)

Two new commands stored on mission state. At save time (`MISSION:SAVE`), the extension resolves incomplete pairs:

| focusStart | focusEnd | Result |
|------------|----------|--------|
| set | set | Pass both to web upload |
| set | not set | Fill end with total frame count |
| not set | set | Fill start with 0 |
| not set | not set | Pass nothing |

The resolved pair is sent as `focusStart`/`focusEnd` form fields in the existing web upload request.

### Web

No changes. The upload endpoint already accepts and validates `focusStart`/`focusEnd`.

## Data Flow

```
Mission script → Addon → Extension → Web
                   |         |          |
  OCAP_setFocusStart  :MISSION:FOCUS_START:  upload(focusStart, focusEnd)
  OCAP_setFocusEnd    :MISSION:FOCUS_END:
```

## Usage

```sqf
// Trim prep phase (end auto-filled at save time)
["OCAP_setFocusStart"] call CBA_fnc_serverEvent;

// Explicit frame numbers
["OCAP_setFocusStart", [120]] call CBA_fnc_serverEvent;
["OCAP_setFocusEnd", [850]] call CBA_fnc_serverEvent;

// Mark end of action (start defaults to 0)
["OCAP_setFocusEnd"] call CBA_fnc_serverEvent;
```
