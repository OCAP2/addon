#include "script_component.hpp"

params ["_unit", "_id", "_uid", "_name"];

[":EVENT:",
	[GVAR(captureFrameNo), "disconnected", _name]
] call EFUNC(extension,sendData);

if (_unit getVariable [QGVARMAIN(isInitialized), false]) then {
	_unit setVariable [QGVARMAIN(exclude), true];
};

format[
  "0,Event=Bookmark|Player %1 (%2) has left",
  _name,
  _uid
] call EFUNC(tacview,sendData);
