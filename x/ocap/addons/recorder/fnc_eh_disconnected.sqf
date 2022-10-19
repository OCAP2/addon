/*
  FILE: fnc_eh_disconnected.sqf

  FUNCTION: OCAP_recorder_fnc_eh_disconnected

  Description:

    This function uses the <OCAP_EH_HandleDisconnect> event handler to log "disconnected" events to the timeline. It will exclude any body left over from further recording.

  Parameters:
    See the wiki for details. <https://community.bistudio.com/wiki/Arma_3:_Mission_Event_Handlers#HandleDisconnect>

  Returns:
    False [Bool]

  Examples:
    > call FUNC(eh_disconnected);

  Public:
    No

  Author:
    IndigoFox
*/

#include "script_component.hpp"

params ["_unit", "_id", "_uid", "_name"];

[":EVENT:",
	[GVAR(captureFrameNo), "disconnected", _name]
] call EFUNC(extension,sendData);

if (_unit getVariable [QGVARMAIN(isInitialized), false]) then {
	_unit setVariable [QGVARMAIN(exclude), true];
};

false;
