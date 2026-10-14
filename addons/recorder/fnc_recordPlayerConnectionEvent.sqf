/* ----------------------------------------------------------------------------
FILE: fnc_recordPlayerConnectionEvent.sqf

FUNCTION: OCAP_recorder_fnc_recordPlayerConnectionEvent

Description:
  Records a player connection event when a recording session is available.
  Events outside a recording are discarded; recording start takes a snapshot
  of the players who are still connected instead.

Parameters:
  _eventType - "connected" or "disconnected" [String]
  _name      - Player name [String]
  _uid       - Player UID [String]
  _frame     - Recording frame, defaults to the current capture frame [optional, Number]

Returns:
  Nothing

Public:
  No
---------------------------------------------------------------------------- */

#include "script_component.hpp"

params ["_eventType", "_name", "_uid", ["_frame", GVAR(captureFrameNo), [0]]];

if (!EGVAR(extension,sessionReady)) exitWith {};
// startRecording sets recording before the startup snapshot, while captureLoop
// sets startTime afterwards. A paused recording keeps startTime and its events.
if (isNil QGVAR(startTime) && {!GVAR(recording)}) exitWith {};

private _extraData = createHashMap;

if (EGVAR(settings,includeSteamIdInPlayerConnectionEvents)) then {
  _extraData set ["playerUid", _uid];
};

private _eventData = [
  _frame max 1,
  _eventType,
  _name,
  [_extraData] call CBA_fnc_encodeJSON
];

[":EVENT:GENERAL:", _eventData] call EFUNC(extension,sendData);
