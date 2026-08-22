/* ----------------------------------------------------------------------------
FILE: fnc_getAutoStartPlayerCount.sqf

FUNCTION: OCAP_recorder_fnc_getAutoStartPlayerCount

Description:
  Returns the number of players eligible for automatic recording start. The
  configured headless-client exclusion is applied here for both initial start
  and automatic restart checks.

Returns:
  Eligible player count [Number]

Public:
  No
---------------------------------------------------------------------------- */

#include "script_component.hpp"

private _players = allPlayers;

if (EGVAR(settings,excludeHeadlessClientsFromAutoStart)) then {
  _players = _players - (entities "HeadlessClient_F");
};

count _players
