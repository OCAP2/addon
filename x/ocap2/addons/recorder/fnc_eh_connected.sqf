#include "script_component.hpp"

params ["_id", "_uid", "_name", "_jip", "_owner", "_idstr"];

// skip for server 'connected' message
if ((_this#0) isEqualTo 2) exitWith {};

// log to timeline
[":EVENT:",
  [GVAR(captureFrameNo), "connected", _this select 2]
] call EFUNC(extension,sendData);

format[
  "0,Event=Bookmark|Player %1 (%2) has joined",
  _name,
  _uid
] call EFUNC(tacview,sendData);

[_id] call FUNC(adminUIcontrol);
