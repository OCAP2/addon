// After a lot of determination, in the end, engine limitations in Arma 3 with clientside projectile simulation means that the best source of truth for state is the owner.

// To achieve this, we'll do a few things.
// First, we'll remoteExec three functions to all clients:
// eh_fired_client, eh_fired_clientBullet, and eh_fired_clientProjectile.

// We use a Local EH to detect locality changes and migrate the FiredMan/HandleDamage
// handlers to follow the unit's owner. The Local EH only fires on machines where it
// was added (https://community.bistudio.com/wiki/Arma_3:_Event_Handlers#Local) — since
// OCAP is server-side only, the EH lives on the server. When locality leaves the
// server (e.g. a player slots into a pre-placed AI), the server must remoteExec the
// install code to the new owner; otherwise the player's machine has no FiredMan EH
// and their shots are never recorded.



#include "script_component.hpp"

// OCAP is a server-side addon — clients don't have it installed.
// CBA PREP only runs where the PBO is loaded, so FUNC(eh_fired_client)
// and FUNC(eh_fired_clientBullet) won't exist on clients.
// Send the compiled functions to all clients (JIP-queued for late joiners).
[FUNC(eh_fired_client), {
  missionNamespace setVariable [QFUNC(eh_fired_client), _this];
}] remoteExec ["call", -2, true];
[FUNC(eh_fired_clientBullet), {
  missionNamespace setVariable [QFUNC(eh_fired_clientBullet), _this];
}] remoteExec ["call", -2, true];
[FUNC(eh_fired_clientProjectile), {
  missionNamespace setVariable [QFUNC(eh_fired_clientProjectile), _this];
}] remoteExec ["call", -2, true];

GVAR(trackedProjectiles) = createHashMap;
GVAR(trackedPlacedObjects) = createHashMap;

// Install block — adds the FiredMan/HandleDamage handlers on whichever machine
// owns the unit. FUNC/QGVARMAIN macros are expanded here at compile time on the
// server (the only machine with the PBO). When this code block is shipped to a
// client via remoteExec ["call", ...], it carries the expanded global-variable
// references; `ocap_recorder_fnc_eh_fired_client` is populated on every client by
// the JIP remoteExec at the top of this file.
GVAR(ownerInstallBlock) = {
  // Idempotent: clear any leftover EH from a previous ownership cycle before
  // adding a new one. The server's Local EH cleanup runs server-side only, so
  // a client that previously owned this unit still carries its old EH; if the
  // unit returns to that client we would otherwise stack a second EH and emit
  // duplicate :EVENT:PROJECTILE: records.
  if (_this getVariable [QGVARMAIN(firedManEHExists), false]) then {
    _this removeEventHandler ["FiredMan", _this getVariable QGVARMAIN(firedManEH)];
  };
  private _id = _this addEventHandler ["FiredMan", {
    private _start = diag_tickTime;
    _this call FUNC(eh_fired_client);
    TRACE_1("Ran fired handler",diag_tickTime - _start);
  }];
  _this setVariable [QGVARMAIN(firedManEHExists), true];
  _this setVariable [QGVARMAIN(firedManEH), _id];

  // HandleDamage stores the ammo classname on the victim for kill attribution
  if (_this getVariable [QGVARMAIN(handleDamageEHExists), false]) then {
    _this removeEventHandler ["HandleDamage", _this getVariable QGVARMAIN(handleDamageEH)];
  };
  private _hdId = _this addEventHandler ["HandleDamage", {
    params ["_unit", "", "", "", "_projectile"];
    if (_projectile isNotEqualTo "" && {_projectile isNotEqualTo (_unit getVariable [QGVARMAIN(lastDamageAmmo), ""])}) then {
      _unit setVariable [QGVARMAIN(lastDamageAmmo), _projectile, 2];
    };
  }];
  _this setVariable [QGVARMAIN(handleDamageEHExists), true];
  _this setVariable [QGVARMAIN(handleDamageEH), _hdId];
};

GVAR(ownerRemoveBlock) = {
  if (_this getVariable [QGVARMAIN(firedManEHExists), false]) then {
    _this removeEventHandler ["FiredMan", _this getVariable QGVARMAIN(firedManEH)];
    _this setVariable [QGVARMAIN(firedManEHExists), false];
    _this setVariable [QGVARMAIN(firedManEH), nil];
  };
  if (_this getVariable [QGVARMAIN(handleDamageEHExists), false]) then {
    _this removeEventHandler ["HandleDamage", _this getVariable QGVARMAIN(handleDamageEH)];
    _this setVariable [QGVARMAIN(handleDamageEHExists), false];
    _this setVariable [QGVARMAIN(handleDamageEH), nil];
  };
};

// Now we'll do the server setup.
// Wrap everything in a CBA Class Event Handler so when the server initializes any soldier, it'll set up the Local EH.
["CAManBase", "init", {
  params ["_entity"];

  // When object is inited, add the EH to the owner machine.
  // For local entities (server-owned AI), add directly — remoteExec to owner 0
  // (not-yet-networked entities) causes the object reference to deserialize as null.
  if (local _entity) then {
    _entity call GVAR(ownerInstallBlock);
  } else {
    [_entity, GVAR(ownerInstallBlock)] remoteExec ["call", owner _entity];
  };

  // Local EH on the server detects locality changes. Per BIS wiki, this EH only fires
  // on machines where it was added — since clients don't have OCAP, the EH lives on
  // the server only. We can't rely on a Local EH firing on the new owner: when the
  // server loses locality (player slotting into pre-placed AI is the common case),
  // we must remoteExec the install to the new owner. When the server regains locality
  // (e.g. owner disconnect), we install directly here.
  _entity addEventHandler ["Local", {
    params ["_entity", "_isLocal"];

    if (_isLocal) then {
      // Server gained locality — install on server directly.
      _entity call GVAR(ownerInstallBlock);
    } else {
      // Server lost locality — clean up server EHs and install on the new owner.
      // `owner _entity` returns the new owner at this point (locality has already changed).
      _entity call GVAR(ownerRemoveBlock);
      [_entity, GVAR(ownerInstallBlock)] remoteExec ["call", owner _entity];
    };
  }];

// for the class event handler,
// allow inheritance, don't exclude anything, and apply retroactively
}, true, [], true] call CBA_fnc_addClassEventHandler;


// Finally, we'll add a CBA Event Handler to take in the pre-processed fired data here on the server and send it to the extension.
[QGVARMAIN(handleFiredManData), {
  params ["_data"];
  // Receive array from server, hc, or client.
  TRACE_1("Sending fired data to extension",_data);
  _data spawn {
    sleep 2;
    [":EVENT:PROJECTILE:", _this] call EFUNC(extension,sendData);
  };
}] call CBA_fnc_addEventHandler;

// Handle placed object creation events (mines, explosives)
// ID assignment happens here because GVAR(nextId) only exists on the server
[QGVARMAIN(handlePlacedData), {
  params ["_data", "_projectile"];
  private _placedId = GVAR(nextId);
  GVAR(nextId) = GVAR(nextId) + 1;
  _data set [1, _placedId];
  _projectile setVariable [QGVARMAIN(placedId), _placedId, true];
  TRACE_2("Sending placed object data to extension",_placedId,_data);
  [":PLACED:CREATE:", _data] call EFUNC(extension,sendData);

  // Track placed object for server-side fallback — when the placer disconnects
  // the mine transfers to the server and client-side Explode/Deleted EHs are lost.
  // A periodic check (below) detects the locality change and re-adds the EHs.
  // (Local EH is not supported on mine/explosive objects.)
  GVAR(trackedPlacedObjects) set [_placedId, _projectile];
}] call CBA_fnc_addEventHandler;

// Handle placed object lifecycle events (detonation, deletion)
[QGVARMAIN(handlePlacedEvent), {
  params ["_data"];
  TRACE_1("Sending placed event data to extension",_data);
  [":PLACED:EVENT:", _data] call EFUNC(extension,sendData);
}] call CBA_fnc_addEventHandler;

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

// Placed object locality check — detect mines/explosives that transferred to
// the server (e.g. placer disconnected) and re-add lifecycle EHs.
// Local EH is not supported on mine objects, so we poll instead.
[{
  private _toRemove = [];
  {
    private _obj = _y;
    if (isNull _obj) then {
      _toRemove pushBack _x;
    } else {
      if (local _obj && {!(_obj getVariable [QGVARMAIN(serverPlacedEHs), false])}) then {
        _obj setVariable [QGVARMAIN(serverPlacedEHs), true];
        _obj setVariable [QGVARMAIN(detonated), false];

        _obj addEventHandler ["Explode", {
          params ["_projectile", "_pos"];
          if (_projectile getVariable [QGVARMAIN(detonated), true]) exitWith {};
          _projectile setVariable [QGVARMAIN(detonated), true];
          private _placedId = _projectile getVariable [QGVARMAIN(placedId), -1];
          [QGVARMAIN(handlePlacedEvent), [[
            GVAR(captureFrameNo), _placedId, "detonated", _pos joinString ","
          ]]] call CBA_fnc_localEvent;
        }];

        _obj addEventHandler ["Deleted", {
          params ["_projectile"];
          if (_projectile getVariable [QGVARMAIN(detonated), true]) exitWith {};
          _projectile setVariable [QGVARMAIN(detonated), true];
          private _placedId = _projectile getVariable [QGVARMAIN(placedId), -1];
          [QGVARMAIN(handlePlacedEvent), [[
            GVAR(captureFrameNo), _placedId, "deleted", (getPosASL _projectile) joinString ","
          ]]] call CBA_fnc_localEvent;
        }];

        TRACE_1("Added server-side EHs to placed object after locality transfer",_x);
      };
    };
  } forEach GVAR(trackedPlacedObjects);
  { GVAR(trackedPlacedObjects) deleteAt _x } forEach _toRemove;
}, 30] call CBA_fnc_addPerFrameHandler;
