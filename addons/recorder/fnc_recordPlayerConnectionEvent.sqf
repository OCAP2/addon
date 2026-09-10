/* ----------------------------------------------------------------------------
FILE: fnc_recordPlayerConnectionEvent.sqf

FUNCTION: OCAP_recorder_fnc_recordPlayerConnectionEvent

Description:
  Records a player connection event immediately when a recording session is
  available, or buffers it for frame 0 of the next recording.

Parameters:
  _eventType - "connected" or "disconnected" [String]
  _name      - Player name [String]
  _uid       - Player UID [String]

Returns:
  Nothing

Public:
  No
---------------------------------------------------------------------------- */

#include "script_component.hpp"

params ["_eventType", "_name", "_uid"];

if (isNil QGVAR(startTime) || {!EGVAR(extension,sessionReady)}) exitWith {
  if (EGVAR(settings,bufferPlayerConnectionEvents)) then {
    GVAR(connectedPlayerNamesBuffer) pushBack [_eventType, _name, _uid];
  };
};

private _extraData = createHashMap;

if (EGVAR(settings,includeSteamIdInPlayerConnectionEvents)) then {
  _extraData set ["playerUid", _uid];
};

private _eventData = [
  GVAR(captureFrameNo),
  _eventType,
  _name,
  [_extraData] call CBA_fnc_encodeJSON
];

[":EVENT:GENERAL:", _eventData] call EFUNC(extension,sendData);
