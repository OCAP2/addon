/* ----------------------------------------------------------------------------
FILE: fnc_eh_projectileHit.sqf

FUNCTION: OCAP_recorder_fnc_eh_projectileHit

Description:
  Tracks when a unit is hit/takes damage and saves to the timeline. This is called by projectile event handlers in <OCAP_recorder_fnc_eh_firedMan>.

Parameters:
  _unit - Object that took damage [Object]
  _shooter - Object that caused the damage [Object]

Returns:
  Nothing

Examples:
  > [_hitEntity, _projectileOwner] call FUNC(eh_projectileHit);

Public:
  No

Author:
  IndigoFox, Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {};

params ["_unit", "_shooter"];

private _hitFrame = GVAR(captureFrameNo);

_unitID = _unit getVariable [QGVARMAIN(id), -1];
if (_unitID == -1) exitWith {};
_shooterID = _shooter getVariable [QGVARMAIN(id), -1];
if (_shooterID == -1) exitWith {};

private _distanceInfo = 0;
_distanceInfo = round (_shooter distance _unit);

_causedByInfo = [
  _shooterID,
  ([_shooter] call FUNC(getEventWeaponText))
];

private _eventData = [
  _hitFrame, // Frame number
  "hit", // event type
  _unitID, // hit unit ID
  _causedByInfo, // event info
  _distanceInfo // distance
];

[":EVENT:", _eventData] call EFUNC(extension,sendData);

if (GVARMAIN(isDebug)) then {
  OCAPEXTLOG(ARR4("HIT EVENT", _hitFrame, _unitID, _causedById));
};
