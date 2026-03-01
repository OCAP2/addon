# Non-Bullet Projectile Server-Side Lifecycle — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move non-bullet projectile tracking from client-side data accumulation to server-side lifecycle, eliminating data loss from locality transfer on dedicated servers.

**Architecture:** Non-bullet projectiles (grenades, smoke, rockets, flares) stream position/hit data to the server via CBA events. The server accumulates this data in a hashmap and sends the final `EVENT:PROJECTILE` to the extension when the projectile is done. Bullets (`shotBullet`) remain fully client-side — unchanged. A client-generated temp key correlates events without requiring a server round-trip for ID assignment.

**Tech Stack:** SQF (Arma 3), CBA framework (event handlers, per-frame handlers)

**Design doc:** `docs/plans/2026-03-01-projectile-server-lifecycle-design.md`

---

### Task 1: Create `fnc_eh_fired_clientProjectile.sqf`

**Files:**
- Create: `addons/recorder/fnc_eh_fired_clientProjectile.sqf`

**Step 1: Create the new function file**

This file sets up event handlers on non-bullet projectiles that stream data to the server instead of accumulating locally. It mirrors the structure of `fnc_eh_fired_clientBullet.sqf` but replaces local array writes with CBA server events.

Key design elements:
- Receives `[_projectile, _tempKey]` where `_tempKey` is the client-generated correlation key
- Uses a shared `_state` array (`[sent]`) passed by reference to both the Deleted EH (via projectile variable) and the PFH (via args) to prevent duplicate "done" signals
- HitExplosion pre-processes `_hitThings` client-side (sort by radius, top 5) before sending
- PFH acts as failsafe sender when `isNull _projectile` — sends `handleProjectileDone` if not already sent

```sqf
// Non-bullet projectile event handler setup (runs on projectile owner)
// Streams position/hit data to the server instead of accumulating locally.
// See fnc_eh_fired_clientBullet.sqf for the bullet-only (client-side) equivalent.
#include "script_component.hpp"
params ["_projectile", "_tempKey"];

if (isNil "_projectile") exitWith {
  WARNING("ClientProjectile EHs: _projectile is nil");
};

// Shared sent flag — prevents duplicate done signals between Deleted EH and PFH.
// Array passed by reference: Deleted EH reads via projectile variable, PFH via args.
private _state = [false];
_projectile setVariable [QGVARMAIN(projectileState), _state];

// HitExplosion — explosive detonation near entities
_projectile addEventHandler ["HitExplosion", {
  params ["_projectile", "_hitEntity", "_projectileOwner", "_hitThings"];
  TRACE_4("HitExplosion",_projectile,_hitEntity,_projectileOwner,_hitThings);

  if (isNull _hitEntity) exitWith {};
  private _hitOcapId = _hitEntity getVariable [QGVARMAIN(id), -1];
  if (_hitOcapId isEqualTo -1) exitWith {};
  if (count _hitThings isEqualTo 0) exitWith {};

  // Sort by radius (largest first), keep top 5, extract component names
  private _hitThings = _hitThings apply {[_x#3, _x#2]};
  _hitThings sort true;
  _hitThings = _hitThings select [0, 5 min (count _hitThings)];

  private _tempKey = _projectile getVariable QGVARMAIN(projectileTempKey);
  [QGVARMAIN(handleProjectileHit), [_tempKey, [
    _hitOcapId,
    _hitThings apply {_x#1},
    (getPosASL _projectile) joinString ",",
    EGVAR(recorder,captureFrameNo)
  ], [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    (getPosASL _projectile) joinString ","
  ]]] call CBA_fnc_serverEvent;
}];

// HitPart — direct projectile impact on vehicle/unit part
_projectile addEventHandler ["HitPart", {
  params ["_projectile", "_hitEntity", "_projectileOwner", "_pos", "_velocity", "_normal", "_component", "_radius", "_surfaceType"];
  TRACE_4("HitPart",_hitEntity,_component,_radius,_surfaceType);

  if (isNull _hitEntity) exitWith {};
  private _hitOcapId = _hitEntity getVariable [QGVARMAIN(id), -1];
  if (_hitOcapId isEqualTo -1) exitWith {};

  private _tempKey = _projectile getVariable QGVARMAIN(projectileTempKey);
  [QGVARMAIN(handleProjectileHit), [_tempKey, [
    _hitOcapId,
    _component,
    (getPosASL _projectile) joinString ",",
    EGVAR(recorder,captureFrameNo)
  ], [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    _pos joinString ","
  ]]] call CBA_fnc_serverEvent;
}];

// Deflected — ricochet, log position
_projectile addEventHandler ["Deflected", {
  params ["_projectile", "_pos", "_velocity", "_hitObject"];
  TRACE_4("Deflected",_projectile,_pos,_velocity,_hitObject);

  private _tempKey = _projectile getVariable QGVARMAIN(projectileTempKey);
  [QGVARMAIN(handleProjectilePos), [_tempKey, [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    _pos joinString ","
  ]]] call CBA_fnc_serverEvent;
}];

// Explode — detonation, log position
_projectile addEventHandler ["Explode", {
  params ["_projectile", "_pos", "_velocity"];
  TRACE_3("Explode",_projectile,_pos,_velocity);

  private _tempKey = _projectile getVariable QGVARMAIN(projectileTempKey);
  [QGVARMAIN(handleProjectilePos), [_tempKey, [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    _pos joinString ","
  ]]] call CBA_fnc_serverEvent;
}];

// Deleted — send done signal to server
_projectile addEventHandler ["Deleted", {
  params ["_projectile"];
  private _state = _projectile getVariable [QGVARMAIN(projectileState), [false]];
  if (_state select 0) exitWith {};
  _state set [0, true];

  private _tempKey = _projectile getVariable QGVARMAIN(projectileTempKey);
  [QGVARMAIN(handleProjectileDone), [_tempKey, [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    (getPosASL _projectile) joinString ","
  ]]] call CBA_fnc_serverEvent;
}];

// PFH — periodic position sampling + failsafe done signal
// _state passed by reference in args — survives projectile deletion
[{
  params ["_args", "_handle"];
  _args params ["_projectile", "_tempKey", "_state"];
  if (isNull _projectile) exitWith {
    if !(_state select 0) then {
      _state set [0, true];
      [QGVARMAIN(handleProjectileDone), [_tempKey]] call CBA_fnc_serverEvent;
    };
    [_handle] call CBA_fnc_removePerFrameHandler;
  };
  [QGVARMAIN(handleProjectilePos), [_tempKey, [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    (getPosASL _projectile) joinString ","
  ]]] call CBA_fnc_serverEvent;
}, EGVAR(settings,frameCaptureDelay), [_projectile, _tempKey, _state]] call CBA_fnc_addPerFrameHandler;

// Store temp key on projectile for EH access
_projectile setVariable [QGVARMAIN(projectileTempKey), _tempKey];

TRACE_1("Finished applying projectile EHs",_projectile);
true
```

**Step 2: Commit**

```bash
git add addons/recorder/fnc_eh_fired_clientProjectile.sqf
git commit -m "feat: add fnc_eh_fired_clientProjectile for server-side lifecycle"
```

---

### Task 2: Register the new function

**Files:**
- Modify: `addons/recorder/XEH_prep.sqf:27` (after `eh_fired_clientBullet`)

**Step 1: Add PREP macro**

Add `PREP(eh_fired_clientProjectile);` after line 27 (`PREP(eh_fired_clientBullet);`):

```sqf
PREP(eh_fired_clientBullet);
PREP(eh_fired_clientProjectile);
```

**Step 2: Commit**

```bash
git add addons/recorder/XEH_prep.sqf
git commit -m "feat: register eh_fired_clientProjectile in XEH_prep"
```

---

### Task 3: Add server-side handlers in `fnc_eh_fired_server.sqf`

**Files:**
- Modify: `addons/recorder/fnc_eh_fired_server.sqf`

**Step 1: Distribute new function to clients**

After line 23 (the existing `remoteExec` for `eh_fired_clientBullet`), add distribution for the new function:

```sqf
[FUNC(eh_fired_clientProjectile), {
  missionNamespace setVariable [QFUNC(eh_fired_clientProjectile), _this];
}] remoteExec ["call", -2, true];
```

**Step 2: Initialize trackedProjectiles hashmap**

Add after the new `remoteExec` block (before the `CAManBase` init class EH):

```sqf
GVAR(trackedProjectiles) = createHashMap;
```

**Step 3: Add four CBA event handlers**

Add after the existing `handlePlacedEvent` handler (after line 181), before the end of the file:

```sqf
// Handle non-bullet projectile lifecycle — server accumulates data from clients
// and sends EVENT:PROJECTILE when the projectile is done.

// Initial projectile data from client — store in hashmap
[QGVARMAIN(handleProjectileInit), {
  params ["_tempKey", "_data"];
  TRACE_2("Projectile init",_tempKey,_data select 17);
  GVAR(trackedProjectiles) set [_tempKey, [_data, diag_tickTime]];
}] call CBA_fnc_addEventHandler;

// Position update from client — append to stored positions array
[QGVARMAIN(handleProjectilePos), {
  params ["_tempKey", "_pos"];
  private _entry = GVAR(trackedProjectiles) get _tempKey;
  if (isNil "_entry") exitWith {};
  ((_entry select 0) select 14) pushBack _pos;
}] call CBA_fnc_addEventHandler;

// Hit event from client — append hit data and position
[QGVARMAIN(handleProjectileHit), {
  params ["_tempKey", "_hitData", "_pos"];
  private _entry = GVAR(trackedProjectiles) get _tempKey;
  if (isNil "_entry") exitWith {};
  private _data = _entry select 0;
  (_data select 16) pushBack _hitData;
  (_data select 14) pushBack _pos;
}] call CBA_fnc_addEventHandler;

// Projectile done signal — send accumulated data to extension and clean up
[QGVARMAIN(handleProjectileDone), {
  params ["_tempKey", ["_finalPos", []]];
  private _entry = GVAR(trackedProjectiles) getOrDefault [_tempKey, []];
  if (_entry isEqualTo []) exitWith {
    TRACE_1("Projectile done for unknown key (already sent or timed out)",_tempKey);
  };
  private _data = _entry select 0;
  if (count _finalPos > 0) then {
    (_data select 14) pushBack _finalPos;
  };
  GVAR(trackedProjectiles) deleteAt _tempKey;
  TRACE_1("Projectile done, sending to extension",_tempKey);
  [QGVARMAIN(handleFiredManData), [_data]] call CBA_fnc_localEvent;
}] call CBA_fnc_addEventHandler;

// Timeout PFH — clean up orphaned projectiles every 30s
// Covers edge cases where client crashes or PFH failsafe doesn't fire
[{
  private _toRemove = [];
  private _now = diag_tickTime;
  {
    (_y) params ["_data", "_creationTime"];
    if (_now - _creationTime > 120) then {
      _toRemove pushBack _x;
      TRACE_1("Projectile timeout, sending data",_x);
      [QGVARMAIN(handleFiredManData), [_data]] call CBA_fnc_localEvent;
    };
  } forEach GVAR(trackedProjectiles);
  { GVAR(trackedProjectiles) deleteAt _x } forEach _toRemove;
}, 30] call CBA_fnc_addPerFrameHandler;
```

**Step 3: Commit**

```bash
git add addons/recorder/fnc_eh_fired_server.sqf
git commit -m "feat: add server-side projectile lifecycle handlers"
```

---

### Task 4: Route non-bullet projectiles through new path in `fnc_eh_fired_client.sqf`

**Files:**
- Modify: `addons/recorder/fnc_eh_fired_client.sqf:177-198` (the else branch after placed objects)

**Step 1: Replace the routing logic**

Replace lines 177-198 (the `} else {` block containing submunitions and bullet routing) with:

```sqf
} else {
  // carryover variables to submunitions
  if ((_data select 17) isEqualTo "shotSubmunitions") then {
    _projectile addEventHandler ["SubmunitionCreated", {
      params ["_projectile", "_submunitionProjectile"];
      private _data = +(_projectile getVariable QGVARMAIN(projectileData));
      _data set [17, getText(configOf _submunitionProjectile >> "simulation")]; // actual sim type
      _data set [18, true]; // isSub = true
      (_data select 14) pushBack [
        diag_tickTime,
        EGVAR(recorder,captureFrameNo),
        (getPosASL _submunitionProjectile) joinString ","
      ];
      _submunitionProjectile setVariable [QGVARMAIN(projectileData), _data];

      // Route child based on simulation type
      if ((_data select 17) isEqualTo "shotBullet") then {
        [_submunitionProjectile] call FUNC(eh_fired_clientBullet);
      } else {
        // Non-bullet submunition — server-side lifecycle
        private _counter = missionNamespace getVariable ["OCAP_projectileCounter", 0];
        missionNamespace setVariable ["OCAP_projectileCounter", _counter + 1];
        private _tempKey = format ["%1_%2", clientOwner, _counter];
        [QGVARMAIN(handleProjectileInit), [_tempKey, _data]] call CBA_fnc_serverEvent;
        [_submunitionProjectile, _tempKey] call FUNC(eh_fired_clientProjectile);
      };
    }];
  } else {
    if ((_data select 17) isEqualTo "shotBullet") then {
      // Bullet — client-side lifecycle (unchanged)
      [_projectile] call FUNC(eh_fired_clientBullet);
    } else {
      // Non-bullet projectile — server-side lifecycle
      private _counter = missionNamespace getVariable ["OCAP_projectileCounter", 0];
      missionNamespace setVariable ["OCAP_projectileCounter", _counter + 1];
      private _tempKey = format ["%1_%2", clientOwner, _counter];
      [QGVARMAIN(handleProjectileInit), [_tempKey, _data]] call CBA_fnc_serverEvent;
      [_projectile, _tempKey] call FUNC(eh_fired_clientProjectile);
    };
  };
};
```

**Step 2: Commit**

```bash
git add addons/recorder/fnc_eh_fired_client.sqf
git commit -m "feat: route non-bullet projectiles through server-side lifecycle"
```

---

### Task 5: Clean up `fnc_eh_fired_clientBullet.sqf` — remove non-bullet workarounds

**Files:**
- Modify: `addons/recorder/fnc_eh_fired_clientBullet.sqf`

This file was modified in PR #88 to add a PFH failsafe and sent flag for non-bullet projectiles. Since non-bullets now go through `fnc_eh_fired_clientProjectile`, remove these workarounds and return this file to bullets-only.

**Step 1: Remove sent flag initialization**

Remove lines 24-25:
```sqf
// Sent flag (index 20) — prevents duplicate sends between Deleted EH and PFH failsafe
_data set [20, false];
```

**Step 2: Remove sent flag checks from Deleted EH**

In the Deleted EH (lines 128-141), remove the sent flag logic. Change from:

```sqf
_projectile addEventHandler ["Deleted", {
	params ["_projectile"];
  private _data = _projectile getVariable QGVARMAIN(projectileData);
  if (isNil "_data") exitWith {};
  if (_data select 20) exitWith {}; // already sent by PFH failsafe
  _data set [20, true];
  (_data select 14) pushBack [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    (getPosASL _projectile) joinString ","
  ];
  TRACE_1("Projectile data",_data);
  [QGVARMAIN(handleFiredManData), [_data]] call CBA_fnc_serverEvent;
}];
```

To:

```sqf
_projectile addEventHandler ["Deleted", {
	params ["_projectile"];
  private _data = _projectile getVariable QGVARMAIN(projectileData);
  if (isNil "_data") exitWith {};
  (_data select 14) pushBack [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    (getPosASL _projectile) joinString ","
  ];
  TRACE_1("Projectile data",_data);
  [QGVARMAIN(handleFiredManData), [_data]] call CBA_fnc_serverEvent;
}];
```

**Step 3: Remove PFH failsafe block**

Remove lines 143-164 (the entire `if ((_data select 17) isNotEqualTo "shotBullet")` block with the PFH):

```sqf
// Periodic position sampling for non-bullet projectiles (runs on owning client)
// Passes _data by reference in args so it survives projectile deletion.
// Acts as failsafe sender when the Deleted EH doesn't fire (e.g. locality
// transfer on dedicated server, or engine cleanup bypassing Deleted).
if ((_data select 17) isNotEqualTo "shotBullet") then {
  [{
    params ["_args", "_handle"];
    _args params ["_projectile", "_data"];
    if (isNull _projectile) exitWith {
      if !(_data select 20) then {
        _data set [20, true];
        [QGVARMAIN(handleFiredManData), [_data]] call CBA_fnc_serverEvent;
      };
      [_handle] call CBA_fnc_removePerFrameHandler;
    };
    (_data select 14) pushBack [
      diag_tickTime,
      EGVAR(recorder,captureFrameNo),
      (getPosASL _projectile) joinString ","
    ];
  }, EGVAR(settings,frameCaptureDelay), [_projectile, _data]] call CBA_fnc_addPerFrameHandler;
};
```

**Step 4: Commit**

```bash
git add addons/recorder/fnc_eh_fired_clientBullet.sqf
git commit -m "refactor: remove non-bullet workarounds from clientBullet (now in clientProjectile)"
```

---

### Task 6: Update file comment headers

**Files:**
- Modify: `addons/recorder/fnc_eh_fired_clientBullet.sqf:1-2` (update comment to clarify bullets-only scope)
- Modify: `addons/recorder/fnc_eh_fired_server.sqf:1-5` (update comments to mention new function distribution)

**Step 1: Update clientBullet header**

Change lines 1-2 from:
```sqf
// This function will receive an existing projectile or submunition and add the rest of the projectile event handlers.
// These state handlers will track changes in bullet trajectory and its impact on nearby units.
```

To:
```sqf
// Bullet-only projectile event handlers (shotBullet simulation type).
// Accumulates trajectory and hit data locally, sends to server on Deleted EH.
// Non-bullet projectiles use fnc_eh_fired_clientProjectile.sqf (server-side lifecycle).
```

**Step 2: Update server header**

Change lines 3-5 from:
```sqf
// First, we'll remoteExec two functions to all clients.
// The first,
```

To:
```sqf
// First, we'll remoteExec three functions to all clients:
// eh_fired_client, eh_fired_clientBullet, and eh_fired_clientProjectile.
```

**Step 3: Commit all changes**

```bash
git add addons/recorder/fnc_eh_fired_clientBullet.sqf addons/recorder/fnc_eh_fired_server.sqf
git commit -m "docs: update file headers for projectile tracking split"
```

---

### Task 7: Manual testing checklist

No automated tests exist for this SQF codebase. Verify on a dedicated server:

**Test 1 — Bullet tracking (unchanged)**
1. Fire an LMG (shotBullet) — check extension log for `EVENT:PROJECTILE` with `sim=shotBullet`
2. Verify positions array has entries
3. Verify no `handleProjectileInit` log entries for bullets

**Test 2 — Smoke grenade (non-bullet, long-lived)**
1. Throw a smoke grenade — check extension log for `EVENT:PROJECTILE` with `sim=shotSmokeX`
2. Verify positions array has multiple entries (PFH sampling)
3. Verify the event arrives even if thrown right before disconnecting

**Test 3 — Frag grenade (non-bullet, short-lived)**
1. Throw an RGO grenade near AI — check for `EVENT:PROJECTILE` with hit data
2. Verify hitParts array is populated
3. Verify positions show trajectory

**Test 4 — Submunition (shotgun/cluster)**
1. Fire a shotgun (shotSubmunitions parent → shotBullet children) — verify children tracked as bullets
2. If available: fire cluster munition (shotSubmunitions → non-bullet children) — verify children tracked via server lifecycle

**Test 5 — Client disconnect resilience**
1. Throw a smoke grenade and immediately disconnect
2. Server should receive data via timeout (120s) if PFH failsafe doesn't fire
3. Check extension log for the projectile event

**Test 6 — RPT log clean**
1. Check server and client RPT for any script errors related to projectile tracking
