/* ----------------------------------------------------------------------------
Script: ocap_fnc_updateTime

Description:
	Sends server's system time, mission environment date/time, time multiplier setting, and time since mission start (post-briefing) to the extension. Will run on a recurring basis as part of <ocap_fnc_startCaptureLoop> if the setting in userconfig.hpp is configured to do so. This is required in missions that utilize time acceleration or have time skips as part of mission flow.

Parameters:
	_date - A manual in-game time to check. [optional, Array]

Returns:
	Nothing

Examples:
	--- Code
	[] call ocap_fnc_updateTime;
	---

Public:
	No

Author:
	Fank
---------------------------------------------------------------------------- */

#include "script_macros.hpp"

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
	ocap_captureFrameNo,
	format _systemTimeFormat,
	format _missionDateFormat,
	timeMultiplier,
	time
]] call ocap_fnc_extension;
