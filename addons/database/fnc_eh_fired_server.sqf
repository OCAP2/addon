// After a lot of determination, in the end, engine limitations in Arma 3 with clientside projectile simulation means that the best source of truth for state is the owner.

// To achieve this, we'll do a few things.
// First, we'll remoteExec two functions to all clients.
// The first,

// We'll use the Local EH to detect changes of unit locality. Add the EH for the soldier unit on the new owner, and remove it on the old. This EH only triggers on two machines so it limits the overall impact of doing so and validates duplicate records are not sent to the server.
// https://community.bistudio.com/wiki/Arma_3:_Event_Handlers#Local



#include "script_component.hpp"

// We need to ensure that the handleFiredMan function exists on the clients we expect to run it.
// So we'll send the function to all clients and define it.
// We need to make sure the function is available at the new name on the server, since it may be running these as well as the owner of AI.
// FUNCMAIN(handleFiredMan) = ocap_fnc_handleFiredMan
[FUNC(eh_fired_client), {
  TRACE_1("Defining ocap_fnc_handleFiredMan",QFUNCMAIN(handleFiredMan));
  missionNamespace setVariable [QFUNCMAIN(handleFiredMan), _this];
}] remoteExec ["call", 0, true];
// FUNCMAIN(addBulletEH) = ocap_fnc_addBulletEH
[FUNC(eh_fired_clientBullet), {
  TRACE_1("Defining ocap_fnc_addBulletEH",QFUNCMAIN(addBulletEH));
  missionNamespace setVariable [QFUNCMAIN(addBulletEH), _this];
}] remoteExec ["call", 0, true];

// Now we'll do the server setup.
// Wrap everything in a CBA Class Event Handler so when the server initializes any soldier, it'll set up the Local EH. The Local EH is global (ironically) when applied to a unit so it'll do what we need across the entire session and trigger the relevant machines on locality change.
["CAManBase", "init", {
  params ["_entity"];

  // When object is inited, add the EH to the owner machine.
  [_entity, {
    private _id = _this addEventHandler ["FiredMan", {
      TRACE_2("FiredMan EH fired",clientOwner,_this);
      private _start = diag_tickTime;
      _this call FUNCMAIN(handleFiredMan);
      TRACE_1("Ran fired handler",diag_tickTime - _start);
    }];
    _this setVariable [QGVARMAIN(firedManEHExists), true];
    _this setVariable [QGVARMAIN(firedManEH), _id];
  }] remoteExec ["call", owner _entity];


  // Again, we will add a single Local EH for the unit on the server, but it has global effect so this is sufficient.
  _entity addEventHandler ["Local", {
    // This code will be run on both the machine giving up ownership and the machine receiving ownership.
    params ["_entity", "_isLocal"];

    // If the unit is NO LONGER local, remove the EH and the CBA EH.
    // We need to see if it exists already.
    private _firedManEHExists = _entity getVariable [QGVARMAIN(firedManEHExists), false];

    // If the unit is NO LONGER local, and the EH exists, remove it.
    if (!_isLocal && _firedManEHExists) then {
      _entity removeEventHandler ["FiredMan", _entity getVariable QGVARMAIN(firedManEH)];
      _entity setVariable [QGVARMAIN(firedManEHExists), false];
      _entity setVariable [QGVARMAIN(firedManEH), nil];
    };

    // If the unit is NOW local and the EH doesn't exist, add it.
    if (_isLocal && !_firedManEHExists) then {
      private _id = _entity addEventHandler ["FiredMan", {
        TRACE_2("FiredMan EH fired",clientOwner,_this);
        private _start = diag_tickTime;
        _this call FUNCMAIN(handleFiredMan);
        TRACE_1("Ran fired handler",diag_tickTime - _start);
      }];
      _entity setVariable [QGVARMAIN(firedManEHExists), true];
      _entity setVariable [QGVARMAIN(firedManEH), _id];
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
