// After a lot of determination, in the end, engine limitations in Arma 3 with clientside projectile simulation means that the best source of truth for state is the owner.

// To achieve this, we'll do a few things.
// First, we'll remoteExec three functions to all clients:
// eh_fired_client, eh_fired_clientBullet, and eh_fired_clientProjectile.

// We'll use the Local EH to detect changes of unit locality. Add the EH for the soldier unit on the new owner, and remove it on the old. This EH only triggers on two machines so it limits the overall impact of doing so and validates duplicate records are not sent to the server.
// https://community.bistudio.com/wiki/Arma_3:_Event_Handlers#Local



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

// Now we'll do the server setup.
// Wrap everything in a CBA Class Event Handler so when the server initializes any soldier, it'll set up the Local EH. The Local EH is global (ironically) when applied to a unit so it'll do what we need across the entire session and trigger the relevant machines on locality change.
["CAManBase", "init", {
  params ["_entity"];

  // When object is inited, add the EH to the owner machine.
  // For local entities (server-owned AI), add directly — remoteExec to owner 0
  // (not-yet-networked entities) causes the object reference to deserialize as null.
  if (local _entity) then {
    private _id = _entity addEventHandler ["FiredMan", {
      private _start = diag_tickTime;
      _this call FUNC(eh_fired_client);
      TRACE_1("Ran fired handler",diag_tickTime - _start);
    }];
    _entity setVariable [QGVARMAIN(firedManEHExists), true];
    _entity setVariable [QGVARMAIN(firedManEH), _id];

    // HandleDamage stores the ammo classname on the victim for kill attribution
    private _hdId = _entity addEventHandler ["HandleDamage", {
      params ["_unit", "", "", "", "_projectile"];
      if (_projectile isNotEqualTo "" && {_projectile isNotEqualTo (_unit getVariable [QGVARMAIN(lastDamageAmmo), ""])}) then {
        _unit setVariable [QGVARMAIN(lastDamageAmmo), _projectile, 2];
      };
    }];
    _entity setVariable [QGVARMAIN(handleDamageEHExists), true];
    _entity setVariable [QGVARMAIN(handleDamageEH), _hdId];
  } else {
    [_entity, {
      private _id = _this addEventHandler ["FiredMan", {
        private _start = diag_tickTime;
        _this call FUNC(eh_fired_client);
        TRACE_1("Ran fired handler",diag_tickTime - _start);
      }];
      _this setVariable [QGVARMAIN(firedManEHExists), true];
      _this setVariable [QGVARMAIN(firedManEH), _id];

      private _hdId = _this addEventHandler ["HandleDamage", {
        params ["_unit", "", "", "", "_projectile"];
        if (_projectile isNotEqualTo "" && {_projectile isNotEqualTo (_unit getVariable [QGVARMAIN(lastDamageAmmo), ""])}) then {
          _unit setVariable [QGVARMAIN(lastDamageAmmo), _projectile, 2];
        };
      }];
      _this setVariable [QGVARMAIN(handleDamageEHExists), true];
      _this setVariable [QGVARMAIN(handleDamageEH), _hdId];
    }] remoteExec ["call", owner _entity];
  };


  // Again, we will add a single Local EH for the unit on the server, but it has global effect so this is sufficient.
  _entity addEventHandler ["Local", {
    // This code will be run on both the machine giving up ownership and the machine receiving ownership.
    params ["_entity", "_isLocal"];

    // If the unit is NO LONGER local, remove the EH and the CBA EH.
    // We need to see if it exists already.
    private _firedManEHExists = _entity getVariable [QGVARMAIN(firedManEHExists), false];
    private _handleDamageEHExists = _entity getVariable [QGVARMAIN(handleDamageEHExists), false];

    // If the unit is NO LONGER local, and the EH exists, remove it.
    if (!_isLocal && _firedManEHExists) then {
      _entity removeEventHandler ["FiredMan", _entity getVariable QGVARMAIN(firedManEH)];
      _entity setVariable [QGVARMAIN(firedManEHExists), false];
      _entity setVariable [QGVARMAIN(firedManEH), nil];
    };
    if (!_isLocal && _handleDamageEHExists) then {
      _entity removeEventHandler ["HandleDamage", _entity getVariable QGVARMAIN(handleDamageEH)];
      _entity setVariable [QGVARMAIN(handleDamageEHExists), false];
      _entity setVariable [QGVARMAIN(handleDamageEH), nil];
    };

    // If the unit is NOW local and the EH doesn't exist, add it.
    if (_isLocal && !_firedManEHExists) then {
      private _id = _entity addEventHandler ["FiredMan", {
        TRACE_2("FiredMan EH fired",clientOwner,_this);
        private _start = diag_tickTime;
        _this call FUNC(eh_fired_client);
        TRACE_1("Ran fired handler",diag_tickTime - _start);
      }];
      _entity setVariable [QGVARMAIN(firedManEHExists), true];
      _entity setVariable [QGVARMAIN(firedManEH), _id];
    };
    if (_isLocal && !_handleDamageEHExists) then {
      private _hdId = _entity addEventHandler ["HandleDamage", {
        params ["_unit", "", "", "", "_projectile"];
        if (_projectile isNotEqualTo "" && {_projectile isNotEqualTo (_unit getVariable [QGVARMAIN(lastDamageAmmo), ""])}) then {
          _unit setVariable [QGVARMAIN(lastDamageAmmo), _projectile, 2];
        };
      }];
      _entity setVariable [QGVARMAIN(handleDamageEHExists), true];
      _entity setVariable [QGVARMAIN(handleDamageEH), _hdId];
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

  // Server-side fallback: when the placer disconnects the mine transfers to
  // the server and the client-side Explode/Deleted EHs are lost.  Re-add them
  // here via the Local EH so detonation is still captured.
  _projectile addEventHandler ["Local", {
    params ["_entity", "_isLocal"];
    if (!_isLocal) exitWith {};
    // Mine just became local to this machine (server) — add lifecycle EHs
    _entity setVariable [QGVARMAIN(detonated), false];

    _entity addEventHandler ["Explode", {
      params ["_projectile", "_pos"];
      if (_projectile getVariable [QGVARMAIN(detonated), true]) exitWith {};
      _projectile setVariable [QGVARMAIN(detonated), true];
      private _placedId = _projectile getVariable [QGVARMAIN(placedId), -1];
      [QGVARMAIN(handlePlacedEvent), [[
        GVAR(captureFrameNo), _placedId, "detonated", _pos joinString ","
      ]]] call CBA_fnc_localEvent;
    }];

    _entity addEventHandler ["Deleted", {
      params ["_projectile"];
      if (_projectile getVariable [QGVARMAIN(detonated), true]) exitWith {};
      _projectile setVariable [QGVARMAIN(detonated), true];
      private _placedId = _projectile getVariable [QGVARMAIN(placedId), -1];
      [QGVARMAIN(handlePlacedEvent), [[
        GVAR(captureFrameNo), _placedId, "deleted", (getPosASL _projectile) joinString ","
      ]]] call CBA_fnc_localEvent;
    }];
  }];
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
