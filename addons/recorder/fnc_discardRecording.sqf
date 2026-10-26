/* ----------------------------------------------------------------------------
FILE: fnc_discardRecording.sqf

FUNCTION: OCAP_recorder_fnc_discardRecording

Description:
  Ends the current recording without saving it, for a mission that ended
  before the recording reached <OCAP_settings_minMissionTime>.

  Not saving is not enough on its own: with the websocket storage the web
  server already holds the streamed recording and would save it as partial
  once the game server moves on. :MISSION:DISCARD: tells the extension to
  drop it instead; it answers with :MISSION:DISCARDED: (see
  <OCAP_extension_fnc_initSession>).

  A mission registered with the extension whose capture never began, for
  example one paused while it registered, has its registration discarded
  without telling players. Does nothing when no recording has started.

Parameters:
  _reason - Why the recording is not saved, shown to players [String]

Returns:
  Nothing

Examples:
  > ["it was shorter than the minimum duration"] call FUNC(discardRecording);

Public:
  No

Author:
  Smith
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params [["_reason", "", [""]]];

if (isNil QGVAR(startTime)) exitWith {
  if (!EGVAR(extension,sessionReady)) exitWith {
    LOG("Discard requested, but recording of this session hasn't started.");
  };
  // The mission is registered with the extension, but nothing was captured:
  // drop the registration, players were never told recording started.
  INFO_1("Discarding the registered mission; nothing was captured: %1",_reason);
  if (isNil {[":MISSION:DISCARD:", []] call EFUNC(extension,sendData)}) then {
    WARNING("The extension did not accept the discard; storage may keep the empty recording");
  };
  EGVAR(extension,sessionReady) = false;
  GVAR(recording) = false;
  publicVariable QGVAR(recording);
};

call FUNC(stopRecording);
private _endFrameNumber = GVAR(captureFrameNo);
call FUNC(removeCaptureHandlers);

INFO_3("Discarding recording — mission: %1 | frames: %2 | reason: %3",GVAR(missionName),_endFrameNumber,_reason);
if (isNil {[":MISSION:DISCARD:", []] call EFUNC(extension,sendData)}) then {
  // An older extension, or a save still in progress. No :MISSION:DISCARDED: follows.
  WARNING("The extension did not accept the discard; storage may keep the recording");
};
OCAPEXTLOG(ARR4("Discarded recording of mission",GVAR(missionName),"because",_reason));

[format["OCAP did not save %1: %2", briefingName, _reason], 1, [1, 1, 1, 1]] remoteExec ["CBA_fnc_notify", [0, -2] select isDedicated];
[[briefingName, _endFrameNumber, _reason], {
  params ["_missionName", "_endFrame", "_reason"];

  player setDiarySubjectPicture [
    "OCAPInfo",
    "\A3\ui_f\data\igui\cfg\simpleTasks\types\danger_ca.paa"
  ];
  player createDiaryRecord [
    "OCAPInfo",
    [
      "Status",
      format[
        "<font color='#FFFF33'>OCAP capture of %1 with %2 frames was not saved: %3.</font>",
        _missionName,
        _endFrame,
        _reason
      ]
    ]
  ];
}] remoteExec ["call", [0, -2] select isDedicated, true];

call FUNC(resetRecording);
