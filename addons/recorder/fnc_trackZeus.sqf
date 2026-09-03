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

{
  private _unitId = _x getVariable [QGVARMAIN(id), -1];
  if (_unitId < 0) then {continue};

  private _owner = _x getVariable ["bis_fnc_moduleRemoteControl_owner", objNull];
  private _curatorId = if (isNull _owner) then {-1} else {[_owner] call FUNC(ensureZeusEntity)};
  private _prevId = _x getVariable [QGVAR(lastZeusCuratorId), -1];
  if (_curatorId isEqualTo _prevId) then {continue};
  _x setVariable [QGVAR(lastZeusCuratorId), _curatorId];

  if (_prevId >= 0) then {
    [":EVENT:GENERAL:", [
      GVAR(captureFrameNo) max 0,
      "zeusRemoteControl",
      [createHashMapFromArray [
        ["curatorId", _prevId],
        ["unitId", _unitId],
        ["active", false]
      ]] call CBA_fnc_encodeJSON
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
      ]] call CBA_fnc_encodeJSON
    ]] call EFUNC(extension,sendData);
  };
} forEach (values GVAR(trackedUnits));
