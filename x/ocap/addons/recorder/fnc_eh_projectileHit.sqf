/* ----------------------------------------------------------------------------
Script: FUNC(eh_hit)

Description:
  Tracks when a unit is hit/takes damage. This is the code triggered by the "MPHit" Event Handler applied to units during <FUNC(addUnitEventHandlers)>.

Parameters:
  _unit - Object the event handler is assigned to. [Object]
  _causedBy - Object that caused the damage. Contains the unit itself in case of collisions. [Object]
  _damage - Level of damage caused by the hit. [Number]
  _instigator - Object - Person who pulled the trigger. [Object]

Returns:
  Nothing

Examples:
  --- Code
  ---

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
