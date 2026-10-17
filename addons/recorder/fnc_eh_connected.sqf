/*
  FILE: fnc_eh_connected.sqf

  FUNCTION: OCAP_recorder_fnc_eh_connected

  Description:

    This function uses the <OCAP_EH_Connected> event handler to log "connected" events to the timeline.

  Parameters:
    See the wiki for details. <https://community.bistudio.com/wiki/Arma_3:_Mission_Event_Handlers#PlayerConnected>

  Returns:
    Nothing

  Examples:
    > call FUNC(eh_connected);

  Public:
    No

  Author:
    IndigoFox
*/

#include "script_component.hpp"
params ["_id", "_uid", "_name", "_jip", "_owner", "_idstr"];

// skip for server 'connected' message
if (_owner isEqualTo 2) exitWith {};

// Log during an active session. Recording start snapshots current players.
["connected", _name, _uid] call FUNC(recordPlayerConnectionEvent);
