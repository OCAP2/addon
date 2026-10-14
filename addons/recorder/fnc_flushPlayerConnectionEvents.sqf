/* ----------------------------------------------------------------------------
FILE: fnc_flushPlayerConnectionEvents.sqf

FUNCTION: OCAP_recorder_fnc_flushPlayerConnectionEvents

Description:
  Records a snapshot of currently connected human players at the first recorded
  frame. No connection history is retained between recordings.

Returns:
  Nothing

Public:
  No
---------------------------------------------------------------------------- */

#include "script_component.hpp"

if (!EGVAR(settings,bufferPlayerConnectionEvents)) exitWith {};

{
  ["connected", name _x, getPlayerUID _x, 1] call FUNC(recordPlayerConnectionEvent);
} forEach (allPlayers - (entities "HeadlessClient_F"));
