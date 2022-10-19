/*
  FILE: fnc_eh_connected.sqf

  FUNCTION: OCAP_recorder_fnc_eh_connected

  Description:

    This function uses the <OCAP_EH_Connected> event handler to log "connected" events to the timeline.

    It also calls <OCAP_recorder_fnc_adminUIControl> to apply the admin UI if the player is in <OCAP_administratorList>.

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

// log to timeline
[":EVENT:",
  [GVAR(captureFrameNo), "connected", _this select 2]
] call EFUNC(extension,sendData);

// trigger admin control check for all connecting players
[_idstr, "connect"] call FUNC(adminUIcontrol);
