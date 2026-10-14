/* ----------------------------------------------------------------------------
FILE: fnc_trackZeus.sqf

FUNCTION: OCAP_recorder_fnc_trackZeus

Description:
  Server-only poll of Zeus occupancy. Discovers curator players via
  allCurators and records start/stop of vanilla/ACE remote control from the
  globally broadcast bis_fnc_moduleRemoteControl_owner variable.

  UAV terminal and custom selectPlayer possession are left alone.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(trackZeus);

Public:
  No

Author:
  OCAP Improved
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!isServer || {!SHOULDSAVEEVENTS} || {!EGVAR(extension,sessionReady)}) exitWith {};
if !(EGVAR(settings,trackZeus)) exitWith {};

if (isNil QGVAR(zeusByUid)) then {GVAR(zeusByUid) = createHashMap};

{
  [getAssignedCuratorUnit _x] call FUNC(ensureZeusEntity);
} forEach allCurators;

if (isNil QGVAR(trackedUnits)) exitWith {};

// VARIABLE: OCAP_recorder_zeusControlledUnits
// OCAP id -> unit, for every unit currently recorded as remote controlled. Those
// are the only units that can still owe a "stopped" event once nobody is able to
// start a new remote control.
if (isNil QGVAR(zeusControlledUnits)) then {GVAR(zeusControlledUnits) = createHashMap};

// This runs every capture frame, and trackedUnits keeps every corpse until it is
// deleted -- several hundred on a long mission. Only a living unit can be taken
// over, and only while some curator is assigned to a player; a unit that is
// already controlled is always checked so its release (on death, on the Zeus
// leaving) is still written exactly when the owner variable clears.
private _hasZeus = (allCurators findIf {!isNull getAssignedCuratorUnit _x}) > -1;
// The controlled-unit map is edited inside the loop, so walk a copy of it; it
// holds a handful of units at most. trackedUnits itself is never edited here.
private _candidates = if (_hasZeus) then {GVAR(trackedUnits)} else {+GVAR(zeusControlledUnits)};

{
  private _unitId = _x;
  private _unit = _y;
  if (_unitId < 0) then {continue};
  if (isNull _unit) then {
    GVAR(zeusControlledUnits) deleteAt _unitId;
    continue;
  };
  if (!alive _unit && {!(_unitId in GVAR(zeusControlledUnits))}) then {continue};

  private _owner = _unit getVariable ["bis_fnc_moduleRemoteControl_owner", objNull];
  private _curatorId = if (isNull _owner) then {-1} else {[_owner] call FUNC(ensureZeusEntity)};
  private _prevId = _unit getVariable [QGVAR(lastZeusCuratorId), -1];
  if (_curatorId isEqualTo _prevId) then {continue};
  _unit setVariable [QGVAR(lastZeusCuratorId), _curatorId];
  if (_curatorId >= 0) then {
    GVAR(zeusControlledUnits) set [_unitId, _unit];
  } else {
    GVAR(zeusControlledUnits) deleteAt _unitId;
  };

  if (_prevId >= 0) then {
    [":EVENT:GENERAL:", [
      GVAR(captureFrameNo) max 0,
      "zeusRemoteControl",
      [createHashMapFromArray [
        ["curatorId", _prevId],
        ["unitId", _unitId],
        ["active", false]
      ]] call FUNC(encodeJSON)
    ]] call EFUNC(extension,sendData);
  };

  if (_curatorId >= 0) then {
    [":EVENT:GENERAL:", [
      GVAR(captureFrameNo) max 0,
      "zeusRemoteControl",
      [createHashMapFromArray [
        ["curatorId", _curatorId],
        ["unitId", _unitId],
        ["playerUid", getPlayerUID _owner],
        ["playerName", name _owner],
        ["active", true]
      ]] call FUNC(encodeJSON)
    ]] call EFUNC(extension,sendData);
  };
} forEach _candidates;
