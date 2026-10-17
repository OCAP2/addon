/* ----------------------------------------------------------------------------
FILE: fnc_submitZeusModule.sqf

FUNCTION: OCAP_recorder_fnc_submitZeusModule

Description:
  Server-side trust boundary for Zeus module placements. CuratorObjectPlaced
  only fires where the curator logic is local, so the Zeus client reports the
  placement through the player-tracking bootstrap. Most ZEN/ACE modules delete
  the logic in the same frame, which is why the client samples class, English
  name and position before the remoteExec.

  curatorId is derived here from the passed Zeus object. The attached target
  id is derived from the passed object, not from the payload.

Parameters:
  _zeus - The curator player whose client observed the placement. [Object]
  _attached - Object the module was dropped on, or objNull. [Object]
  _payload - Client-sampled class, English display name, category, source, x, y,
    and optional attachedName. [HashMap]

Returns:
  Nothing

Examples:
  > [player, _attached, _payload] remoteExecCall [QFUNC(submitZeusModule), 2];

Public:
  No

Author:
  OCAP Improved
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!isServer || {!SHOULDSAVEEVENTS} || {!EGVAR(extension,sessionReady)}) exitWith {};
if !(EGVAR(settings,trackZeus)) exitWith {};
if !(EGVAR(settings,trackZeusModules)) exitWith {};

params [
  ["_zeus", objNull, [objNull]],
  ["_attached", objNull, [objNull]],
  ["_payload", createHashMap, [createHashMap]]
];

if (isNull _zeus) exitWith {};
if (isMultiplayer && {isRemoteExecuted} && {remoteExecutedOwner isNotEqualTo owner _zeus}) exitWith {};
if (isNull getAssignedCuratorLogic _zeus) exitWith {};

private _curatorId = [_zeus] call FUNC(ensureZeusEntity);
if (_curatorId < 0) exitWith {};

private _className = _payload getOrDefault ["className", ""];
private _displayName = _payload getOrDefault ["displayName", ""];
private _xPos = _payload getOrDefault ["x", -1e10];
private _yPos = _payload getOrDefault ["y", -1e10];
if (!(_className isEqualType "") || {_className isEqualTo ""}) exitWith {};
if (!(_displayName isEqualType "") || {_displayName isEqualTo ""}) exitWith {};
if (_xPos isEqualTo -1e10 || {_yPos isEqualTo -1e10}) exitWith {};

private _source = _payload getOrDefault ["source", "other"];
if !(_source in ["zen", "zenCustom", "ace", "vanilla", "other"]) then {_source = "other"};

private _category = _payload getOrDefault ["category", ""];
if !(_category isEqualType "") then {_category = ""};

private _event = createHashMapFromArray [
  ["curatorId", _curatorId],
  ["curatorName", name _zeus],
  ["className", _className],
  ["displayName", _displayName],
  ["category", _category],
  ["source", _source],
  ["x", _xPos],
  ["y", _yPos]
];

if (!isNull _attached) then {
  private _attachedId = _attached getVariable [QGVARMAIN(id), -1];
  if (_attachedId >= 0) then {
    _event set ["attachedUnitId", _attachedId];
  };
  private _attachedName = _payload getOrDefault ["attachedName", ""];
  if (_attachedName isEqualTo "") then {
    if (_attached isKindOf "CAManBase") then {
      _attachedName = name _attached;
    };
  };
  if (_attachedName isNotEqualTo "") then {
    _event set ["attachedName", _attachedName];
  };
};

[":EVENT:GENERAL:", [
  GVAR(captureFrameNo) max 0,
  "zeusModule",
  [_event] call FUNC(encodeJSON)
]] call EFUNC(extension,sendData);
