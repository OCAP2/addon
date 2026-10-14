/* ----------------------------------------------------------------------------
FILE: fnc_ensureZeusEntity.sqf

FUNCTION: OCAP_recorder_fnc_ensureZeusEntity

Description:
  Allocates a stable OCAP id for a Zeus player the first time they are seen
  and writes a <zeusEntity> event. The addon is server-only; this runs on the
  server from the capture loop or from a client camera sample.

  The id is taken from <OCAP_recorder_nextId> but no :SOLDIER:CREATE: is sent,
  so unmodified OCAP readers never see a VIRTUAL unit. Playback synthesizes
  the entity from the event.

Parameters:
  _unit - The curator player unit (getAssignedCuratorUnit or remote-control owner). [Object]

Returns:
  The curatorId, or -1 if the unit cannot be identified. [Number]

Examples:
  > [_owner] call FUNC(ensureZeusEntity);

Public:
  No

Author:
  OCAP Improved
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!isServer || {!SHOULDSAVEEVENTS} || {!EGVAR(extension,sessionReady)}) exitWith {-1};
if !(EGVAR(settings,trackZeus)) exitWith {-1};

params [["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith {-1};

private _uid = getPlayerUID _unit;
if (_uid isEqualTo "") exitWith {-1};

if (isNil QGVAR(zeusByUid)) then {GVAR(zeusByUid) = createHashMap};

private _existing = GVAR(zeusByUid) getOrDefault [_uid, -1];
if (_existing >= 0) exitWith {
  _unit setVariable [QGVAR(zeusId), _existing];
  _existing
};

private _id = GVAR(nextId);
GVAR(nextId) = GVAR(nextId) + 1;
GVAR(zeusByUid) set [_uid, _id];
_unit setVariable [QGVAR(zeusId), _id];

private _bodyId = _unit getVariable [QGVARMAIN(id), -1];
[":EVENT:GENERAL:", [
  GVAR(captureFrameNo) max 0,
  "zeusEntity",
  [createHashMapFromArray [
    ["curatorId", _id],
    ["name", name _unit],
    ["playerUid", _uid],
    ["bodyUnitId", _bodyId]
  ]] call FUNC(encodeJSON)
]] call EFUNC(extension,sendData);

_id
