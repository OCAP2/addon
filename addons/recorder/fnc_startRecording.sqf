/* ----------------------------------------------------------------------------
FILE: fnc_startRecording.sqf

FUNCTION: OCAP_recorder_fnc_startRecording

Description:
  Begins recording the current mission.

  Called via <OCAP_record> via direct CBA event or the administrative diary entry, or by a waiter in <OCAP_recorder_fnc_init> (see <OCAP_settings_autoStart>).

  Will not start recording if <OCAP_recorder_recording> is true and will notify players.

  A fresh recording first registers the mission with the extension (<OCAP_extension_fnc_newMission>)
  and begins the capture once the extension confirms it. Start requests made meanwhile are ignored.

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

// Another start is registering the mission with the extension; it begins the
// capture once the extension confirms it.
if (missionNamespace getVariable [QEGVAR(extension,sessionPending), false]) exitWith {
  INFO("Recording start requested while the mission registers with the extension");
};

// Any explicit or automatic start consumes a pending empty-server restart.
GVAR(autoRestartAfterEmptyPending) = false;

GVAR(recording) = true;
publicVariable QGVAR(recording);

if (GVAR(captureFrameNo) == 0 && {!EGVAR(extension,sessionReady)}) exitWith {
  EGVAR(extension,sessionPending) = true;

  // The mission registers with the extension only now, the first time or
  // after the previous recording was exported or discarded, so a mission
  // that never starts recording is never stored. Storage initialization
  // may still be running and provides the mission context.
  [{!isNil QEGVAR(extension,missionContext)}, {
    call EFUNC(extension,newMission);

    // The extension answers :MISSION:OK: or :MISSION:FAILED:. It may take a
    // while, for example while it still ends the previous recording, and
    // the capture waits for it: starting another registration meanwhile
    // would leave the extension with a mission nothing records.
    [{EGVAR(extension,sessionReady) || {!EGVAR(extension,sessionPending)}}, {
      if (!EGVAR(extension,sessionReady)) exitWith {
        GVAR(recording) = false;
        publicVariable QGVAR(recording);
        ["OCAP failed to start recording: the extension could not start the mission", 1, [1, 0, 0, 1]] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];
      };
      if (missionNamespace getVariable [QGVAR(missionEnded), false]) exitWith {
        INFO("Mission ended before its recording started; discarding the registered mission");
        [":MISSION:DISCARD:", []] call EFUNC(extension,sendData);
        EGVAR(extension,sessionReady) = false;
        GVAR(recording) = false;
        publicVariable QGVAR(recording);
      };
      call FUNC(flushPlayerConnectionEvents);
      call FUNC(captureLoop);
      call FUNC(announceRecording);
    }] call CBA_fnc_waitUntilAndExecute;

    [{EGVAR(extension,sessionReady) || {!EGVAR(extension,sessionPending)}}, {}, [], 30, {
      WARNING("The extension has not confirmed the mission after 30 seconds; recording starts once it does");
    }] call CBA_fnc_waitUntilAndExecute;
  }, [], 60, {
    EGVAR(extension,sessionPending) = false;
    GVAR(recording) = false;
    publicVariable QGVAR(recording);
    ERROR("Timeout waiting for extension storage to initialize. Recording will not start.");
    ["OCAP failed to start recording: extension storage is not ready", 1, [1, 0, 0, 1]] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];
  }] call CBA_fnc_waitUntilAndExecute;
};

if (GVAR(captureFrameNo) == 0) then {
  call FUNC(flushPlayerConnectionEvents);
  call FUNC(captureLoop);
};
call FUNC(announceRecording);
