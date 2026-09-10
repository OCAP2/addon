/* ----------------------------------------------------------------------------
FILE: fnc_autoRestartMonitor.sqf

FUNCTION: OCAP_recorder_fnc_autoRestartMonitor

Description:
  Periodically checks whether a recording auto-saved because the server became
  empty and starts a fresh recording after the player threshold is met again.

Returns:
  Nothing

Public:
  No
---------------------------------------------------------------------------- */

#include "script_component.hpp"

if (!EGVAR(settings,autoRestartAfterEmpty)) exitWith {};
if (!GVAR(autoRestartAfterEmptyPending)) exitWith {};
if (GVAR(recording) || {!isNil QGVAR(startTime)}) exitWith {};
if (getClientStateNumber <= 9) exitWith {};

private _playerCount = call FUNC(getAutoStartPlayerCount);
if (_playerCount < EGVAR(settings,minPlayerCount)) exitWith {};

GVAR(autoRestartAfterEmptyPending) = false;
INFO_1("Auto-restarting recording after empty-server save; eligible players: %1",_playerCount);
call FUNC(startRecording);
