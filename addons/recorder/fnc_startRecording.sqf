/* ----------------------------------------------------------------------------
FILE: fnc_startRecording.sqf

FUNCTION: OCAP_recorder_fnc_startRecording

Description:
  Begins recording the current mission.

  Called via <OCAP_record> via direct CBA event or the administrative diary entry, or by a waiter in <OCAP_recorder_fnc_init> (see <OCAP_settings_autoStart>).

  Will not start recording if <OCAP_recorder_recording> is true and will notify players.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(startRecording);

Public:
  No

Author:
  Dell, Zealot, IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

// disregard recording attempts while OCAP is disabled.
if (!GVARMAIN(enabled)) exitWith {};

// if recording started earlier and startTime has been noted, only restart the capture loop with any updated settings.
if (GVAR(recording) && GVAR(captureFrameNo) > 10) exitWith {
  OCAPEXTLOG(["OCAP was asked to record and is already recording!"]);
  [
    ["OCAP was asked to record", 1, [1, 1, 1, 1]],
    ["and is already recording", 1, [1, 1, 1, 1]]
  ] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];
};

GVAR(recording) = true;
publicVariable QGVAR(recording);

private _systemTimeFormat = ["%1-%2-%3T%4:%5:%6.%7"];
_systemTimeFormat append (systemTimeUTC apply {if (_x < 10) then {"0" + str _x} else {str _x}});
private _missionDateFormat = ["%1-%2-%3T%4:%5:00"];
_missionDateFormat append (date apply {if (_x < 10) then {"0" + str _x} else {str _x}});

[[cba_missionTime, format _missionDateFormat, format _systemTimeFormat], { // add diary entry for clients on recording start
  [{!isNull player}, {
    player setDiarySubjectPicture [
      "OCAPInfo",
      "\A3\ui_f\data\igui\cfg\simpleTasks\types\use_ca.paa"
    ];
    player createDiaryRecord [
      "OCAPInfo",
      [
        "Status",
        format["<font color='#33FF33'>OCAP started recording.<br/>In-Mission Time Elapsed: %1<br/>Mission World Time: %2<br/>System Time UTC: %3</font>", _this#0, _this#1, _this#2]
      ]
    ];
  }, _this] call CBA_fnc_waitUntilAndExecute;
}] remoteExec ["call", [0, -2] select isDedicated, true];

if (GVAR(captureFrameNo) == 0) then {
  // Notify the extension
  [":START:", [worldName, GVAR(missionName), getMissionConfigValue ["author", ""], GVAR(frameCaptureDelay)]] call EFUNC(extension,sendData);
  [":SET:VERSION:", [GVARMAIN(version)]] call EFUNC(extension,sendData);
  call FUNC(captureLoop);
};

[QGVARMAIN(customEvent), ["generalEvent", "Recording started."]] call CBA_fnc_serverEvent;
["OCAP began recording", 1, [1, 1, 1, 1]] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];

// Log times
[] call FUNC(updateTime);
