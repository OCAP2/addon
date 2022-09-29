#include "script_component.hpp"

private _systemTimeFormat = ["%1-%2-%3T%4:%5:%6.%7"];
_systemTimeFormat append (systemTimeUTC apply {if (_x < 10) then {"0" + str _x} else {str _x}});
private _missionDateFormat = ["%1-%2-%3T%4:%5:00"];
_missionDateFormat append (date apply {if (_x < 10) then {"0" + str _x} else {str _x}});

[QGVARMAIN(customEvent), ["generalEvent", "Recording paused."]] call CBA_fnc_serverEvent;
["OCAP stopped recording", 1, [1, 1, 1, 1]] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];

GVAR(recording) = false;
publicVariable QGVAR(recording);

[[cba_missionTime, format _missionDateFormat, format _systemTimeFormat], { // add diary entry for clients on recording pause
  [{!isNull player}, {
    player createDiaryRecord [
      "OCAPInfo",
      [
        "Status",
        format["<font color='#33FF33'>OCAP stopped recording.<br/>In-Mission Time Elapsed: %1<br/>Mission World Time: %2<br/>System Time UTC: %3</font>", _this#0, _this#1, _this#2]
      ], taskNull, "", false
    ];
    player setDiarySubjectPicture [
      "OCAPInfo",
      "\A3\ui_f\data\igui\cfg\simpleTasks\types\use_ca.paa"
    ];
  }, _this] call CBA_fnc_waitUntilAndExecute;
}] remoteExecCall ["call", [0, -2] select isDedicated, true];

// Log times
[] call FUNC(updateTime);
