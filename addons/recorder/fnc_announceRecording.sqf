/* ----------------------------------------------------------------------------
FILE: fnc_announceRecording.sqf

FUNCTION: OCAP_recorder_fnc_announceRecording

Description:
  Tells players and the recording that recording started: a diary record, the
  "Recording started." event, a notification, and the time state.

  Called by <OCAP_recorder_fnc_startRecording> once the capture runs. The event
  is only recorded then, and the time state only reaches the extension once the
  mission is registered.

  Raises the server-local CBA event "OCAP_recordingStarted": recording starts
  asynchronously, so a mission script that records its own events or exports
  right after <OCAP_record> can wait for it.

Parameters:
  None

Returns:
  Nothing

Public:
  No

Author:
  Smith
---------------------------------------------------------------------------- */
#include "script_component.hpp"

private _systemTimeFormat = ["%1-%2-%3T%4:%5:%6.%7"];
_systemTimeFormat append (systemTimeUTC apply {if (_x < 10) then {"0" + str _x} else {str _x}});
private _missionDateFormat = ["%1-%2-%3T%4:%5:00"];
_missionDateFormat append (date apply {if (_x < 10) then {"0" + str _x} else {str _x}});

[[format _missionDateFormat, format _systemTimeFormat], { // add diary entry for clients on recording start
  [{!isNull player}, {
    private _t = round cba_missionTime;
    private _elapsedStr = format ["%1:%2", floor (_t / 60), [str (_t mod 60), "0" + str (_t mod 60)] select (_t mod 60 < 10)];
    player setDiarySubjectPicture [
      "OCAPInfo",
      "\A3\ui_f\data\igui\cfg\simpleTasks\types\use_ca.paa"
    ];
    player createDiaryRecord [
      "OCAPInfo",
      [
        "Status",
        format["<font color='#33FF33'>OCAP started recording.<br/>In-Mission Time Elapsed: %1<br/>Mission World Time: %2<br/>System Time UTC: %3</font>", _elapsedStr, _this#0, _this#1]
      ]
    ];
  }, _this] call CBA_fnc_waitUntilAndExecute;
}] remoteExec ["call", [0, -2] select isDedicated, true];

[QGVARMAIN(customEvent), ["generalEvent", "Recording started."]] call CBA_fnc_serverEvent;
["OCAP began recording", 1, [1, 1, 1, 1]] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];

// Log times
[] call FUNC(updateTime);

[QGVARMAIN(recordingStarted), []] call CBA_fnc_localEvent;
