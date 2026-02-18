/* ----------------------------------------------------------------------------
FILE: fnc_stopRecording.sqf

FUNCTION: OCAP_recorder_fnc_stopRecording

Description:
  Stops recording the current mission. Can be used to pause the recording for later resumption. Also called automatically as part of <OCAP_recorder_fnc_exportData>.

  Called via <OCAP_pause> via direct CBA event or the administrative diary entry.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(stopRecording);

Public:
  No

Author:
  Dell, Zealot, IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

private _systemTimeFormat = ["%1-%2-%3T%4:%5:%6.%7"];
_systemTimeFormat append (systemTimeUTC apply {if (_x < 10) then {"0" + str _x} else {str _x}});
private _missionDateFormat = ["%1-%2-%3T%4:%5:00"];
_missionDateFormat append (date apply {if (_x < 10) then {"0" + str _x} else {str _x}});

[QGVARMAIN(customEvent), ["generalEvent", "OCAP paused recording"]] call CBA_fnc_serverEvent;
[localize LSTRING(RecordingPaused), 1, [1, 1, 1, 1]] remoteExec ["CBA_fnc_notify", [0, -2] select isDedicated];

[[cba_missionTime, format _missionDateFormat, format _systemTimeFormat,
  localize LSTRING(Status), localize LSTRING(RecordingPaused), localize LSTRING(InMissionTimeElapsed),
  localize LSTRING(MissionWorldTime), localize LSTRING(SystemTimeUTC)
], { // add diary entry for clients on recording pause
  [{!isNull player}, {
    _this params ["_elapsed", "_missionDate", "_systemTime", "_statusStr", "_pausedStr", "_timeElapsedStr", "_worldTimeStr", "_sysTimeStr"];
    player createDiaryRecord [
      "OCAPInfo",
      [
        _statusStr,
        format["<font color='#33FF33'>%1<br/>%2 %3<br/>%4 %5<br/>%6 %7</font>",
          _pausedStr, _timeElapsedStr, _elapsed,
          _worldTimeStr, _missionDate, _sysTimeStr, _systemTime]
      ]
    ];
    player setDiarySubjectPicture [
      "OCAPInfo",
      "\A3\ui_f\data\igui\cfg\simpleTasks\types\use_ca.paa"
    ];
  }, _this] call CBA_fnc_waitUntilAndExecute;
}] remoteExec ["call", [0, -2] select isDedicated, true];

// Log times
[] call FUNC(updateTime);

GVAR(recording) = false;
publicVariable QGVAR(recording);
