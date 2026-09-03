/* ----------------------------------------------------------------------------
FILE: fnc_submitZeusCamera.sqf

FUNCTION: OCAP_recorder_fnc_submitZeusCamera

Description:
  Server-side trust boundary for Zeus camera samples. Clients have no OCAP
  functions; they remoteExecCall this with their player object and a payload
  sampled from curatorCamera (local to the Zeus machine).

  Identity is derived from the passed object. UAV terminal views are not
  sampled — the client only sends when curatorCamera exists.

Parameters:
  _unit - The Zeus player. [Object]
  _payload - Camera sample (x, y, dir, fov, pitch). [HashMap]

Returns:
  Nothing

Examples:
  > [player, _payload] remoteExecCall [QFUNC(submitZeusCamera), 2];

Public:
  No

Author:
  OCAP Improved
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!isServer || {!SHOULDSAVEEVENTS} || {!EGVAR(extension,sessionReady)}) exitWith {};
if !(EGVAR(settings,trackZeus)) exitWith {};

params [
  ["_unit", objNull, [objNull]],
  ["_payload", createHashMap, [createHashMap]]
];

if (isNull _unit) exitWith {};

private _curatorId = [_unit] call FUNC(ensureZeusEntity);
if (_curatorId < 0) exitWith {};

private _xPos = _payload getOrDefault ["x", -1e10];
private _yPos = _payload getOrDefault ["y", -1e10];
private _dir = _payload getOrDefault ["dir", 0];
private _fov = _payload getOrDefault ["fov", 0.75];
private _pitch = _payload getOrDefault ["pitch", 0];
if (_xPos isEqualTo -1e10 || {_yPos isEqualTo -1e10}) exitWith {};

if (isNil QGVAR(zeusLastCamera)) then {GVAR(zeusLastCamera) = createHashMap};
private _rounded = [round _xPos, round _yPos, round _dir, parseNumber ((_fov toFixed 3)), parseNumber ((_pitch toFixed 2))];
if ((GVAR(zeusLastCamera) getOrDefault [_curatorId, []]) isEqualTo _rounded) exitWith {};
GVAR(zeusLastCamera) set [_curatorId, _rounded];

_payload set ["curatorId", _curatorId];
_payload set ["x", _xPos];
_payload set ["y", _yPos];
_payload set ["dir", _dir];
_payload set ["fov", _fov];
_payload set ["pitch", _pitch];

[":EVENT:GENERAL:", [
  GVAR(captureFrameNo) max 0,
  "zeusCamera",
  [_payload] call CBA_fnc_encodeJSON
]] call EFUNC(extension,sendData);
