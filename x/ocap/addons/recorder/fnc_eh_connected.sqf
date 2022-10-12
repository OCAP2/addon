#include "script_component.hpp"
// PlayerConnected EH
params ["_id", "_uid", "_name", "_jip", "_owner", "_idstr"];

// skip for server 'connected' message
if (_owner isEqualTo 2) exitWith {};

// log to timeline
[":EVENT:",
  [GVAR(captureFrameNo), "connected", _this select 2]
] call EFUNC(extension,sendData);

// trigger admin control check for all connecting players
[_idstr, "connect"] call FUNC(adminUIcontrol);
