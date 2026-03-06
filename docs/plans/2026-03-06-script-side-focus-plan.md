# Script-Side Focus Range — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow mission makers to set a focus range (start/end frames) via SQF script, which flows through the extension to the web upload.

**Architecture:** Two CBA server events in the addon send frame numbers to the extension via new `:MISSION:FOCUS_START:` / `:MISSION:FOCUS_END:` commands. The extension stores them as lifecycle state, resolves incomplete pairs at save time, and includes them in the web upload. No storage interface changes — focus is a lifecycle/upload concern handled in main.go.

**Tech Stack:** SQF (addon), Go (extension), existing web upload API (no web changes)

---

### Task 1: Extension — Add focus fields to UploadMetadata

**Files:**
- Modify: `/home/fank/repo/ocap2-extension/pkg/core/types.go:54-60`

**Step 1: Add fields to UploadMetadata**

```go
// UploadMetadata contains mission information needed for upload.
type UploadMetadata struct {
	WorldName       string
	MissionName     string
	MissionDuration float64
	Tag             string
	EndFrame        Frame
	FocusStart      *Frame
	FocusEnd        *Frame
}
```

`EndFrame` is needed so the MISSION:SAVE handler can fill in a missing `FocusEnd` with the last frame. `FocusStart`/`FocusEnd` are pointer types (nil = not set).

**Step 2: Commit**

```bash
cd /home/fank/repo/ocap2-extension
git add pkg/core/types.go
git commit -m "feat: add focus and EndFrame fields to UploadMetadata"
```

---

### Task 2: Extension — Populate EndFrame in computeExportMetadata

**Files:**
- Modify: `/home/fank/repo/ocap2-extension/internal/storage/memory/memory.go:409-444`

**Step 1: Set EndFrame on the returned metadata**

In `computeExportMetadata()`, after computing `endFrame` (line 414-435) and before the return statement (line 439), set `EndFrame` on the result:

```go
return core.UploadMetadata{
	WorldName:       b.world.WorldName,
	MissionName:     b.mission.MissionName,
	MissionDuration: duration,
	Tag:             b.mission.Tag,
	EndFrame:        endFrame,
}
```

**Step 2: Verify existing tests still pass**

```bash
cd /home/fank/repo/ocap2-extension
go test ./internal/storage/memory/... -v -run TestGetExportMetadata
```

**Step 3: Commit**

```bash
git add internal/storage/memory/memory.go
git commit -m "feat: populate EndFrame in memory backend export metadata"
```

---

### Task 3: Extension — Register focus lifecycle handlers in main.go

**Files:**
- Modify: `/home/fank/repo/ocap2-extension/cmd/ocap_recorder/main.go`

**Step 1: Add package-level focus state variables**

After line 85 (`addonVersion string = "unknown"`), add:

```go
// Focus range: set by :MISSION:FOCUS_START: / :MISSION:FOCUS_END:, cleared on new mission
focusStart *core.Frame
focusEnd   *core.Frame
```

**Step 2: Reset focus in handleNewMission**

In `handleNewMission` (line 289), after `MarkerCache.Reset()` / `EntityCache.Reset()` (lines 303-304), add:

```go
// Reset focus range for new mission
focusStart = nil
focusEnd = nil
```

**Step 3: Register focus handlers in registerLifecycleHandlers**

After the `:MISSION:START:` registration (line 375), add:

```go
d.Register(":MISSION:FOCUS_START:", func(e dispatcher.Event) (any, error) {
	if len(e.Args) < 1 {
		return nil, fmt.Errorf("MISSION:FOCUS_START requires 1 arg (frame)")
	}
	v, err := strconv.ParseUint(strings.TrimSpace(util.TrimQuotes(e.Args[0])), 10, 64)
	if err != nil {
		return nil, fmt.Errorf("invalid focus start frame: %w", err)
	}
	f := core.Frame(v)
	focusStart = &f
	Logger.Info("Focus start set", "frame", f)
	return nil, nil
})

d.Register(":MISSION:FOCUS_END:", func(e dispatcher.Event) (any, error) {
	if len(e.Args) < 1 {
		return nil, fmt.Errorf("MISSION:FOCUS_END requires 1 arg (frame)")
	}
	v, err := strconv.ParseUint(strings.TrimSpace(util.TrimQuotes(e.Args[0])), 10, 64)
	if err != nil {
		return nil, fmt.Errorf("invalid focus end frame: %w", err)
	}
	f := core.Frame(v)
	focusEnd = &f
	Logger.Info("Focus end set", "frame", f)
	return nil, nil
})
```

Add `"strconv"` and `"strings"` to imports if not already present.

**Step 4: Resolve focus pair and set on metadata in MISSION:SAVE handler**

In the `MISSION:SAVE` handler (line 377-408), after `meta := u.GetExportMetadata()` (line 389), add focus resolution:

```go
// Resolve focus range
if focusStart != nil || focusEnd != nil {
	if focusStart != nil {
		meta.FocusStart = focusStart
	} else {
		f := core.Frame(0)
		meta.FocusStart = &f
	}
	if focusEnd != nil {
		meta.FocusEnd = focusEnd
	} else {
		meta.FocusEnd = &meta.EndFrame
	}
}
```

**Step 5: Verify it compiles**

```bash
cd /home/fank/repo/ocap2-extension
go build ./cmd/ocap_recorder/...
```

**Step 6: Commit**

```bash
git add cmd/ocap_recorder/main.go
git commit -m "feat: register MISSION:FOCUS_START/END lifecycle handlers"
```

---

### Task 4: Extension — Send focus fields in API upload

**Files:**
- Modify: `/home/fank/repo/ocap2-extension/internal/api/client.go:68-74`

**Step 1: Add focus form fields to Upload**

After the existing form fields (line 74, `_ = writer.WriteField("tag", meta.Tag)`), add:

```go
if meta.FocusStart != nil {
	_ = writer.WriteField("focusStart", strconv.FormatUint(uint64(*meta.FocusStart), 10))
}
if meta.FocusEnd != nil {
	_ = writer.WriteField("focusEnd", strconv.FormatUint(uint64(*meta.FocusEnd), 10))
}
```

Add `"strconv"` to imports.

**Step 2: Verify it compiles**

```bash
cd /home/fank/repo/ocap2-extension
go build ./...
```

**Step 3: Commit**

```bash
git add internal/api/client.go
git commit -m "feat: include focus range in web upload form fields"
```

---

### Task 5: Extension — Update README

**Files:**
- Modify: `/home/fank/repo/ocap2-extension/README.md:157-165`

**Step 1: Add focus commands to Lifecycle Commands table**

After `:MISSION:SAVE:` row (line 164), add:

```markdown
| `:MISSION:FOCUS_START:` | Set playback focus start frame |
| `:MISSION:FOCUS_END:` | Set playback focus end frame |
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add MISSION:FOCUS_START/END to supported commands"
```

---

### Task 6: Extension — Run all tests

**Step 1: Run full test suite**

```bash
cd /home/fank/repo/ocap2-extension
go test ./... -v
```

Expected: all existing tests pass. No new tests needed — focus handlers are simple lifecycle commands with inline parsing (same pattern as `:SYS:ADDON_VERSION:`), and the UploadMetadata changes are additive (new fields default to nil/zero).

**Step 2: Fix any failures, commit if needed**

---

### Task 7: Addon — Create fnc_setFocusStart.sqf

**Files:**
- Create: `/home/fank/repo/ocap2-addon/addons/recorder/fnc_setFocusStart.sqf`

**Step 1: Write the function**

```sqf
/* ----------------------------------------------------------------------------
FILE: fnc_setFocusStart.sqf

FUNCTION: OCAP_recorder_fnc_setFocusStart

Description:
  Sets the playback focus start frame. If no frame number is provided,
  uses the current capture frame. Sends :MISSION:FOCUS_START: to extension.

Parameters:
  _frameNumber - (optional) explicit frame number [Number]

Returns:
  Nothing

Examples:
  > ["OCAP_setFocusStart"] call CBA_fnc_serverEvent;
  > ["OCAP_setFocusStart", [120]] call CBA_fnc_serverEvent;

Public:
  No

Author:
  Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {};

params [["_frameNumber", GVAR(captureFrameNo), [0]]];

[":MISSION:FOCUS_START:", [_frameNumber]] call EFUNC(extension,sendData);
```

**Step 2: Commit**

```bash
cd /home/fank/repo/ocap2-addon
git add addons/recorder/fnc_setFocusStart.sqf
git commit -m "feat: add fnc_setFocusStart handler"
```

---

### Task 8: Addon — Create fnc_setFocusEnd.sqf

**Files:**
- Create: `/home/fank/repo/ocap2-addon/addons/recorder/fnc_setFocusEnd.sqf`

**Step 1: Write the function**

```sqf
/* ----------------------------------------------------------------------------
FILE: fnc_setFocusEnd.sqf

FUNCTION: OCAP_recorder_fnc_setFocusEnd

Description:
  Sets the playback focus end frame. If no frame number is provided,
  uses the current capture frame. Sends :MISSION:FOCUS_END: to extension.

Parameters:
  _frameNumber - (optional) explicit frame number [Number]

Returns:
  Nothing

Examples:
  > ["OCAP_setFocusEnd"] call CBA_fnc_serverEvent;
  > ["OCAP_setFocusEnd", [850]] call CBA_fnc_serverEvent;

Public:
  No

Author:
  Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {};

params [["_frameNumber", GVAR(captureFrameNo), [0]]];

[":MISSION:FOCUS_END:", [_frameNumber]] call EFUNC(extension,sendData);
```

**Step 2: Commit**

```bash
cd /home/fank/repo/ocap2-addon
git add addons/recorder/fnc_setFocusEnd.sqf
git commit -m "feat: add fnc_setFocusEnd handler"
```

---

### Task 9: Addon — Register functions and CBA events

**Files:**
- Modify: `/home/fank/repo/ocap2-addon/addons/recorder/XEH_prep.sqf:45`
- Modify: `/home/fank/repo/ocap2-addon/addons/recorder/fnc_addEventMission.sqf:302-308`

**Step 1: Add PREP calls to XEH_prep.sqf**

After `PREP(exportData);` (line 45), add:

```sqf
PREP(setFocusStart);
PREP(setFocusEnd);
```

**Step 2: Register CBA events in fnc_addEventMission.sqf**

After the `OCAP_exportData` listener block (after line 308), add:

```sqf

/*
  CBA Event: OCAP_setFocusStart
  Description:
    Sets the playback focus start frame. Uses current capture frame if no
    frame number is provided. Calls <OCAP_recorder_fnc_setFocusStart>.

  Parameters:
    0 - Event name [String]
    1 - Event data [Array]
      1.0 - (optional) Frame number [Number]

  Example:
    > ["OCAP_setFocusStart"] call CBA_fnc_serverEvent;
    > ["OCAP_setFocusStart", [120]] call CBA_fnc_serverEvent;
*/
if (isNil QEGVAR(listener,setFocusStart)) then {
  EGVAR(listener,setFocusStart) = [QGVARMAIN(setFocusStart), {
    _this call FUNC(setFocusStart);
  }] call CBA_fnc_addEventHandler;
  OCAPEXTLOG(["Initialized setFocusStart listener"]);
};

/*
  CBA Event: OCAP_setFocusEnd
  Description:
    Sets the playback focus end frame. Uses current capture frame if no
    frame number is provided. Calls <OCAP_recorder_fnc_setFocusEnd>.

  Parameters:
    0 - Event name [String]
    1 - Event data [Array]
      1.0 - (optional) Frame number [Number]

  Example:
    > ["OCAP_setFocusEnd"] call CBA_fnc_serverEvent;
    > ["OCAP_setFocusEnd", [850]] call CBA_fnc_serverEvent;
*/
if (isNil QEGVAR(listener,setFocusEnd)) then {
  EGVAR(listener,setFocusEnd) = [QGVARMAIN(setFocusEnd), {
    _this call FUNC(setFocusEnd);
  }] call CBA_fnc_addEventHandler;
  OCAPEXTLOG(["Initialized setFocusEnd listener"]);
};
```

**Step 3: Build addon to verify**

```bash
cd /home/fank/repo/ocap2-addon
hemtt build
```

**Step 4: Commit**

```bash
git add addons/recorder/XEH_prep.sqf addons/recorder/fnc_addEventMission.sqf
git commit -m "feat: register OCAP_setFocusStart/End CBA events"
```

---

### Task 10: Addon — Update listener handle documentation

**Files:**
- Modify: `/home/fank/repo/ocap2-addon/addons/recorder/fnc_addEventMission.sqf:127-139`

**Step 1: Add focus listener handles to the Variables doc block**

In the variables documentation block (lines 127-139), add before the closing `*/`:

```sqf
  OCAP_listener_setFocusStart - Handle for <OCAP_setFocusStart> listener.
  OCAP_listener_setFocusEnd - Handle for <OCAP_setFocusEnd> listener.
```

**Step 2: Commit**

```bash
cd /home/fank/repo/ocap2-addon
git add addons/recorder/fnc_addEventMission.sqf
git commit -m "docs: add focus listener handles to variable documentation"
```
