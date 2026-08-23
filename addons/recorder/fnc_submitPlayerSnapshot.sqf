/* ----------------------------------------------------------------------------
FILE: fnc_submitPlayerSnapshot.sqf

FUNCTION: OCAP_recorder_fnc_submitPlayerSnapshot

Description:
  Server-side trust boundary for the player-detail snapshots that clients sample
  locally. Validates the call, derives the identity from the passed object rather
  than the payload, reduces the payload to a diff against the player's previous
  snapshot of the same kind, and forwards it to the extension.

  A snapshot that changed nothing is dropped entirely, and every
  SNAPSHOT_KEYFRAME_EVERY diffs one full snapshot is written so a lost event
  cannot corrupt the rest of the chain.

Parameters:
  _kind - "inventory", "medical", "stamina" or "radio". [String]
  _unit - The unit the snapshot describes. [Object]
  _payload - Sampled data. [HashMap]

Returns:
  Nothing

Examples:
  > ["medical", player, _payload] remoteExecCall [QFUNC(submitPlayerSnapshot), 2];

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

// A full snapshot after this many consecutive diffs bounds how much a dropped
// event can damage, and gives players seeking the recording a cheap resync point.
#define SNAPSHOT_KEYFRAME_EVERY 20

if (!isServer || {!SHOULDSAVEEVENTS} || {!EGVAR(extension,sessionReady)}) exitWith {};

params [
  ["_kind", "", [""]],
  ["_unit", objNull, [objNull]],
  ["_payload", createHashMap, [createHashMap]]
];

private _eventType = switch (_kind) do {
  case "inventory": {"inventorySnapshot"};
  case "medical": {"medicalSnapshot"};
  case "stamina": {"staminaSnapshot"};
  case "radio": {"radioSnapshot"};
  default {""};
};
if (_eventType isEqualTo "" || {isNull _unit}) exitWith {};

private _ocapId = _unit getVariable [QGVARMAIN(id), -1];
if (_ocapId < 0) exitWith {};

_payload set ["unitId", _ocapId];
_payload set ["playerUid", getPlayerUID _unit];

if (isNil QGVAR(playerSnapshotState)) then {GVAR(playerSnapshotState) = createHashMap};

private _frame = GVAR(captureFrameNo);
private _stateKey = format ["%1:%2", _ocapId, _kind];
private _state = GVAR(playerSnapshotState) get _stateKey;
private _diffCount = 0;
private _writeDiff = EGVAR(settings,trackPlayerSnapshotDiffs) && {!isNil "_state"};
private _outgoing = _payload;

if (_writeDiff) then {
  _state params ["_baseFrame", "_basePayload", ["_baseDiffCount", 0]];
  _diffCount = _baseDiffCount;

  ([_basePayload, _payload] call FUNC(diffSnapshotPayload)) params ["_changed", "_removed"];

  switch (true) do {
    case (count _changed == 0 && {_removed isEqualTo []}): {
      // Identical to the previous snapshot, so there is nothing worth recording.
      _outgoing = nil;
    };
    case (_diffCount >= SNAPSHOT_KEYFRAME_EVERY): {
      _writeDiff = false;
    };
    default {
      _outgoing = createHashMapFromArray [
        ["unitId", _ocapId],
        ["diffOf", _baseFrame],
        ["set", _changed]
      ];
      if (_removed isNotEqualTo []) then {_outgoing set ["unset", _removed]};
    };
  };
};

if (isNil "_outgoing") exitWith {};

GVAR(playerSnapshotState) set [_stateKey, [_frame, _payload, [0, _diffCount + 1] select _writeDiff]];

private _command = switch (_kind) do {
  case "inventory": {":PLAYER:INVENTORY:"};
  case "medical": {":PLAYER:MEDICAL:"};
  case "stamina": {":PLAYER:STAMINA:"};
  case "radio": {":PLAYER:RADIO:"};
};

[_command, [_frame, _eventType, [_outgoing] call CBA_fnc_encodeJSON]] call EFUNC(extension,sendData);
