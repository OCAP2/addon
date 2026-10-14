/* ----------------------------------------------------------------------------
FILE: fnc_submitZeusPing.sqf

FUNCTION: OCAP_recorder_fnc_submitZeusPing

Description:
  Server-side trust boundary for player-to-Zeus pings. The vanilla
  "CuratorPinged" event handler only fires where the curator logic is local,
  which is the Zeus's own machine, so the server can never observe a ping
  itself. The Zeus client reports it through the player-tracking bootstrap.

  Identity and position are derived here from the passed objects; the client
  sends nothing but two object references.

  One keypress can fire on every curator that can edit the pinging unit, and
  the key repeats, so both are collapsed by a per-unit dedupe window.

Parameters:
  _zeus - The curator player whose client observed the ping. [Object]
  _pinger - The player who pinged. [Object]

Returns:
  Nothing

Examples:
  > [getAssignedCuratorUnit _curator, _pinger] remoteExecCall [QFUNC(submitZeusPing), 2];

Public:
  No

Author:
  OCAP Improved
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!isServer || {!SHOULDSAVEEVENTS} || {!EGVAR(extension,sessionReady)}) exitWith {};
if !(EGVAR(settings,trackZeus)) exitWith {};
if !(EGVAR(settings,trackZeusPings)) exitWith {};

params [
  ["_zeus", objNull, [objNull]],
  ["_pinger", objNull, [objNull]]
];

if (isNull _pinger) exitWith {};

private _unitId = _pinger getVariable [QGVARMAIN(id), -1];
if (_unitId < 0) exitWith {};

if (isNil QGVAR(zeusPingLast)) then {GVAR(zeusPingLast) = createHashMap};

private _now = CBA_missionTime;
private _window = EGVAR(settings,zeusPingMinInterval);
if (_now - (GVAR(zeusPingLast) getOrDefault [_unitId, -1e10]) < _window) exitWith {};
GVAR(zeusPingLast) set [_unitId, _now];

private _curatorId = if (isNull _zeus) then {-1} else {[_zeus] call FUNC(ensureZeusEntity)};
private _pos = getPosATL _pinger;

[":EVENT:GENERAL:", [
  GVAR(captureFrameNo) max 0,
  "zeusPing",
  [createHashMapFromArray [
    ["curatorId", _curatorId],
    ["unitId", _unitId],
    ["name", name _pinger],
    ["side", str (side group _pinger)],
    ["x", round (_pos select 0)],
    ["y", round (_pos select 1)]
  ]] call FUNC(encodeJSON)
]] call EFUNC(extension,sendData);
