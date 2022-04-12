/*
  Start Recording

  This is the initial recording start function. If it hasn't been called from anywhere already, it'll get everything in order to initiate a session for this mission.
*/
#include "script_component.hpp"

// disregard recording attempts while OCAP is disabled.
if (!GVARMAIN(enabled)) exitWith {};

// if recording started earlier and startTime has been noted, only restart the capture loop with any updated settings.
if (GVAR(recording)) exitWith {
  OCAPEXTLOG(["OCAP2 was asked to record and is already recording!"]);
  [
    ["OCAP2 was asked to record", 1, [1, 1, 1, 1]],
    ["and is already recording", 1, [1, 1, 1, 1]]
  ] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];
};

GVAR(recording) = true;
publicVariable QGVAR(recording);

private _systemTimeFormat = ["%1-%2-%3T%4:%5:%6.%7"];
_systemTimeFormat append (systemTimeUTC apply {if (_x < 10) then {"0" + str _x} else {str _x}});
private _missionDateFormat = ["%1-%2-%3T%4:%5:00"];
_missionDateFormat append (date apply {if (_x < 10) then {"0" + str _x} else {str _x}});

[QGVARMAIN(customEvent), ["generalEvent", "Recording started."]] call CBA_fnc_serverEvent;
["OCAP2 began recording", 1, [1, 1, 1, 1]] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];

[[cba_missionTime, format _missionDateFormat, format _systemTimeFormat], { // add diary entry for clients on recording start
  [{!isNull player}, {
    player createDiaryRecord [
      "OCAP2Info",
      [
        "Status",
        format["<font color='#33FF33'>OCAP2 started recording.<br/>In-Mission Time Elapsed: %1<br/>Mission World Time: %2<br/>System Time UTC: %3</font>", _this#0, _this#1, _this#2]
      ], taskNull, "", false
    ];
    player setDiarySubjectPicture [
      "OCAP2Info",
      "\A3\ui_f\data\igui\cfg\simpleTasks\types\use_ca.paa"
    ];
  }, _this] call CBA_fnc_waitUntilAndExecute;
}] remoteExecCall ["call", [0, -2] select isDedicated, true];

if (GVAR(captureFrameNo) == 0) then {
  // Notify the extension
  [":START:", [worldName, GVAR(missionName), getMissionConfigValue ["author", ""], GVAR(frameCaptureDelay)]] call EFUNC(extension,sendData);
  [":SET:VERSION:", [GVARMAIN(version)]] call EFUNC(extension,sendData);
  call FUNC(captureLoop);
};

// Log times
[] call FUNC(updateTime);
