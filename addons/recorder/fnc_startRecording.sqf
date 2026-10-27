/* ----------------------------------------------------------------------------
FILE: fnc_startRecording.sqf

FUNCTION: OCAP_recorder_fnc_startRecording

Description:
  Begins recording the current mission.

  Called via <OCAP_record> via direct CBA event or the administrative diary entry, or by a waiter in <OCAP_recorder_fnc_init> (see <OCAP_settings_autoStart>).

  Will not start recording again while the capture runs, and will notify players.

  A fresh recording first registers the mission with the extension (<OCAP_extension_fnc_newMission>)
  and begins the capture once the extension confirms it. Start requests made meanwhile register
  nothing more, but undo a pause.

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

// The capture already runs.
if (GVAR(recording) && {!isNil QGVAR(startTime)}) exitWith {
  OCAPEXTLOG(["OCAP was asked to record and is already recording!"]);
  [
    ["OCAP was asked to record", 1, [1, 1, 1, 1]],
    ["and is already recording", 1, [1, 1, 1, 1]]
  ] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];
};

// Another start is registering the mission with the extension; it begins the
// capture once the extension confirms it. A pause meanwhile is undone. A
// :MISSION:START: the extension has not answered for a minute (a lost
// callback) is given up and sent again. Its token is dropped at once, so a
// late answer to it, even one before the new start goes out, is ignored.
// Waiting for storage, nothing was sent yet, so nothing is resent.
private _pending = missionNamespace getVariable [QEGVAR(extension,sessionPending), false];
private _sentAt = missionNamespace getVariable [QEGVAR(extension,registrationSentAt), -1];
private _pendingFor = [0, diag_tickTime - _sentAt] select (_sentAt >= 0);
if (_pending && {_pendingFor >= 60}) then {
  WARNING_1("The extension has not answered the mission registration for %1 s; registering again",round _pendingFor);
  EGVAR(extension,registrationToken) = nil;
  EGVAR(extension,sessionPending) = false;
  _pending = false;
};
if (_pending) exitWith {
  INFO("Recording start requested while the mission registers with the extension");
  GVAR(heldByPause) = false;
  GVAR(recording) = true;
  publicVariable QGVAR(recording);
  ["OCAP starts recording once the mission is registered", 1, [1, 1, 1, 1]] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];
};

// Any explicit or automatic start consumes a pending empty-server restart.
GVAR(autoRestartAfterEmptyPending) = false;

GVAR(heldByPause) = false;
GVAR(recording) = true;
publicVariable QGVAR(recording);

if (isNil QGVAR(startTime) && {!EGVAR(extension,sessionReady)}) exitWith {
  EGVAR(extension,sessionPending) = true;
  EGVAR(extension,registrationSentAt) = -1; // set by newMission once sent

  // The mission registers with the extension only now, the first time or
  // after the previous recording was exported or discarded, so a mission
  // that never starts recording is never stored. Storage initialization
  // may still be running and provides the mission context; it may take
  // long, for example a websocket server that is slow to answer.
  [{
    !isNil QEGVAR(extension,missionContext) ||
    {missionNamespace getVariable [QEGVAR(extension,storageFailed), false]} ||
    {missionNamespace getVariable [QGVAR(missionEnded), false]}
  }, {
    private _ended = missionNamespace getVariable [QGVAR(missionEnded), false];
    if (_ended || {isNil QEGVAR(extension,missionContext)}) exitWith {
      EGVAR(extension,sessionPending) = false;
      if (!_ended) then {
        ERROR("Extension storage could not be initialized. Recording will not start.");
        if (GVAR(recording)) then {
          ["OCAP failed to start recording: extension storage is not ready", 1, [1, 0, 0, 1]] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];
        };
      };
      GVAR(recording) = false;
      publicVariable QGVAR(recording);
    };
    // Paused while storage initialized: nothing to register yet; the next
    // start does.
    if (!GVAR(recording)) exitWith {
      EGVAR(extension,sessionPending) = false;
      INFO("Recording paused before the mission registered; it registers when recording resumes");
    };
    call EFUNC(extension,newMission);
    // A start that registers again after an unanswered minute supersedes
    // this attempt; its waiters below then leave it to the new one.
    private _token = missionNamespace getVariable [QEGVAR(extension,registrationToken), ""];

    // The extension answers :MISSION:OK: or :MISSION:FAILED:. It may take a
    // while, for example while it still ends the previous recording, and
    // the capture waits for it: starting another registration meanwhile
    // would leave the extension with a mission nothing records.
    [{EGVAR(extension,sessionReady) || {!EGVAR(extension,sessionPending)}}, {
      params ["_token"];
      if (_token isNotEqualTo (missionNamespace getVariable [QEGVAR(extension,registrationToken), ""])) exitWith {};
      if (!isNil QGVAR(startTime)) exitWith {}; // a start in the meantime began the capture
      if (missionNamespace getVariable [QGVAR(missionEnded), false]) exitWith {
        ["the mission ended before the recording began"] call FUNC(discardRecording);
        GVAR(recording) = false;
        publicVariable QGVAR(recording);
      };
      if (!EGVAR(extension,sessionReady)) exitWith {
        if (GVAR(recording)) then { // a paused start was never announced either
          ["OCAP failed to start recording: the extension could not start the mission", 1, [1, 0, 0, 1]] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];
        };
        GVAR(recording) = false;
        publicVariable QGVAR(recording);
      };
      // Paused meanwhile: the capture begins when recording resumes.
      if (!GVAR(recording)) exitWith {
        INFO("Mission registered while recording is paused; the capture begins when it resumes");
      };
      call FUNC(flushPlayerConnectionEvents);
      call FUNC(captureLoop);
      call FUNC(announceRecording);
    }, [_token]] call CBA_fnc_waitUntilAndExecute;

    [{EGVAR(extension,sessionReady) || {!EGVAR(extension,sessionPending)}}, {}, [_token], 30, {
      params ["_token"];
      if (_token isNotEqualTo (missionNamespace getVariable [QEGVAR(extension,registrationToken), ""])) exitWith {};
      // Paused, or the mission ended, meanwhile.
      if (!GVAR(recording) || {missionNamespace getVariable [QGVAR(missionEnded), false]}) exitWith {};
      WARNING("The extension has not confirmed the mission after 30 seconds; recording starts once it does");
      ["OCAP is waiting for the extension to start recording", 1, [1, 1, 0, 1]] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];
    }] call CBA_fnc_waitUntilAndExecute;
  }] call CBA_fnc_waitUntilAndExecute;

  [{!isNil QEGVAR(extension,missionContext) || {!EGVAR(extension,sessionPending)}}, {}, [], 60, {
    // An extension that never reported its version is not running: nothing
    // will initialize storage.
    if (isNil QEGVAR(extension,dllVersion)) exitWith {
      ERROR("The extension is not running. Recording will not start.");
      EGVAR(extension,storageFailed) = true;
    };
    if (!GVAR(recording)) exitWith {}; // paused meanwhile
    WARNING("Extension storage is not initialized after 60 seconds; recording starts once it is");
    ["OCAP is waiting for its storage to start recording", 1, [1, 1, 0, 1]] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];
  }] call CBA_fnc_waitUntilAndExecute;
};

// A paused capture resumes on its own; a registered mission paused before
// its capture began starts it now.
if (isNil QGVAR(startTime)) then {
  call FUNC(flushPlayerConnectionEvents);
  call FUNC(captureLoop);
};
call FUNC(announceRecording);
