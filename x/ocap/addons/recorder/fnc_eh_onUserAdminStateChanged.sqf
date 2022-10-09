#include "script_component.hpp"

params ["_networkId", "_loggedIn", "_votedIn"];

_object = (getUserInfo _networkId) select 10;
if (isNull _object) exitWith {};

_id = getPlayerId _object;

if (_loggedIn && !_votedIn && !(_object getVariable [QGVARMAIN(hasAdminControls), true])) exitWith {
  // if user has become admin by logging, not voting, and has not yet received adminControls per OCAP - Main > Administrators setting, add controls
  [_id, true] call FUNC(adminUIcontrol);
};
if (!_loggedIn && _object getVariable [QGVARMAIN(hasAdminControls), false]) then {
  // if user has logged out, remove adminControls
  [_id, false] call FUNC(adminUIcontrol);
};
