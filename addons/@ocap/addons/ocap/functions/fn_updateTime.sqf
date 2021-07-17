#include "script_macros.hpp"

private _systemTimeFormat = ["%1-%2-%3T%4:%5:%6.%7"];
_systemTimeFormat append (systemTimeUTC apply {if (_x < 10) then {"0" + str _x} else {str _x}});
private _missionDateFormat = ["%1-%2-%3T%4:%5:00"];
_missionDateFormat append (date apply {if (_x < 10) then {"0" + str _x} else {str _x}});

[":TIME:", [
	ocap_captureFrameNo,
	format _systemTimeFormat,
	format _missionDateFormat,
	timeMultiplier,
	time
]] call ocap_fnc_extension;
