#include "script_component.hpp"

params ["_networkId", "_loggedIn", "_votedIn"];

_object = (getUserInfo _networkId) select 10;
if (isNull _object) exitWith {};

if (_loggedIn && !_votedIn) exitWith {
  // if user has become admin by logging, not voting, trigger control addition check
  [_networkId, "login"] call FUNC(adminUIcontrol);
};
if (!_loggedIn) then {
  // if user has logged out, trigger admin control removal
  [_networkId, "logout"] call FUNC(adminUIcontrol);
};
