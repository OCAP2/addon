/* ----------------------------------------------------------------------------
FILE: fnc_flushPlayerConnectionEvents.sqf

FUNCTION: OCAP_recorder_fnc_flushPlayerConnectionEvents

Description:
  Replays buffered player connection events into the newly registered recording
  at frame 0, then clears the buffer.

Returns:
  Nothing

Public:
  No
---------------------------------------------------------------------------- */

#include "script_component.hpp"

{
  _x params ["_eventType", "_name", "_uid"];

  private _extraData = createHashMap;

  if (EGVAR(settings,includeSteamIdInPlayerConnectionEvents)) then {
    _extraData set ["playerUid", _uid];
  };

  private _eventData = [
    0,
    _eventType,
    _name,
    [_extraData] call CBA_fnc_encodeJSON
  ];

  [":EVENT:GENERAL:", _eventData] call EFUNC(extension,sendData);
} forEach GVAR(connectedPlayerNamesBuffer);

GVAR(connectedPlayerNamesBuffer) = [];
