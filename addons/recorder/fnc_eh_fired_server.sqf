// After a lot of determination, in the end, engine limitations in Arma 3 with clientside projectile simulation means that the best source of truth for state is the owner.

// To achieve this, we'll do a few things.
// First, we'll remoteExec two functions to all clients.
// The first,

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
    [":PROJECTILE:", _this] call EFUNC(extension,sendData);
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
  [":NEW:PLACED:", _data] call EFUNC(extension,sendData);
}] call CBA_fnc_addEventHandler;

// Handle placed object lifecycle events (detonation, deletion)
[QGVARMAIN(handlePlacedEvent), {
  params ["_data"];
  TRACE_1("Sending placed event data to extension",_data);
  [":PLACED:EVENT:", _data] call EFUNC(extension,sendData);
}] call CBA_fnc_addEventHandler;
