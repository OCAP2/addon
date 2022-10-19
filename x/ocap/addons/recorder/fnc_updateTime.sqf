/* ----------------------------------------------------------------------------
FILE: fnc_updateTime.sqf

FUNCTION: OCAP_recorder_fnc_updateTime

Description:
	Sends server's system time, mission environment date/time, time multiplier setting, and time since mission start (post-briefing) to the extension. Will run on a recurring basis as part of <FUNC(captureLoop)> if the setting in userconfig.hpp is configured to do so. This is required in missions that utilize time acceleration or have time skips as part of mission flow.

Parameters:
	_date - A manual in-game time to check. [optional, Array]

Returns:
	Nothing

Examples:
	> [] call FUNC(updateTime);

Public:
	No

Author:
	Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params [
  ["_date", []]
];

private _systemTimeFormat = ["%1-%2-%3T%4:%5:%6.%7"];
_systemTimeFormat append (systemTimeUTC apply {if (_x < 10) then {"0" + str _x} else {str _x}});
private _missionDateFormat = ["%1-%2-%3T%4:%5:00"];
if (_date isEqualTo []) then {
  _date = date;
};
_missionDateFormat append (_date apply {if (_x < 10) then {"0" + str _x} else {str _x}});

[":TIME:", [
  GVAR(captureFrameNo),
  format _systemTimeFormat,
  format _missionDateFormat,
  timeMultiplier,
  time
]] call EFUNC(extension,sendData);
