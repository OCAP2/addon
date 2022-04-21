#include "script_component.hpp"

// private _systemTimeFormat = ["%1-%2-%3T%4-%5-%6"];
// _systemTimeFormat append (systemTimeUTC apply {if (_x < 10) then {"0" + str _x} else {str _x}});
// _path = format["%1_%2.txt", (format _systemTimeFormat), missionName];
// "make_file" callExtension (_path + "|" + (GVAR(recordingData) joinString EOL));


{
  "debug_console" callExtension (_x + "~0000")
} forEach GVAR(recordingData);


// _filename = formatText [
// 	"%1\Tacview-%2%3%4-%5%6%7-Arma3-%8.acmi",
// 	TVR_outputPath,
// 	[_year, 4] call CBA_fnc_formatNumber,
// 	[_month, 2] call CBA_fnc_formatNumber,
// 	[_day, 2] call CBA_fnc_formatNumber,
// 	[_hour, 2] call CBA_fnc_formatNumber,
// 	[_minute, 2] call CBA_fnc_formatNumber,
// 	[_second, 2] call CBA_fnc_formatNumber,
// 	worldName
// ];

// ["flashback.saveString", [_filename,GVAR(recordingData)]] call py3_fnc_callExtension
