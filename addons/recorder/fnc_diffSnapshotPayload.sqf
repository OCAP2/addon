/* ----------------------------------------------------------------------------
FILE: fnc_diffSnapshotPayload.sqf

FUNCTION: OCAP_recorder_fnc_diffSnapshotPayload

Description:
  Compares two player-snapshot payloads and returns only what changed.

  Nested HashMaps are walked recursively so a single changed vital does not drag
  the whole medical block along. Arrays are compared as a whole and replaced when
  they differ, because partial array patches would cost more than they save.

Parameters:
  _previous - Payload of the player's previous snapshot of the same kind. [HashMap]
  _current - Payload just sampled. [HashMap]

Returns:
  [_changed, _removed] - Partial payload to merge onto the previous one, and the
  dot-separated paths of keys that no longer exist. [Array]

Examples:
  > ([_old, _new] call FUNC(diffSnapshotPayload)) params ["_changed", "_removed"];

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params [
  ["_previous", createHashMap, [createHashMap]],
  ["_current", createHashMap, [createHashMap]]
];

private _hashMapType = createHashMap;
private _removed = [];

private _walk = {
  params ["_old", "_new", "_prefix"];

  private _changed = createHashMap;
  {
    private _key = _x;
    private _newValue = _y;

    if (!(_key in _old)) then {
      _changed set [_key, _newValue];
    } else {
      private _oldValue = _old get _key;
      if (_newValue isEqualType _hashMapType && {_oldValue isEqualType _hashMapType}) then {
        private _child = [_oldValue, _newValue, _prefix + _key + "."] call _walk;
        if (count _child > 0) then {_changed set [_key, _child]};
      } else {
        if (_newValue isNotEqualTo _oldValue) then {_changed set [_key, _newValue]};
      };
    };
  } forEach _new;

  {
    if (!(_x in _new)) then {_removed pushBack (_prefix + _x)};
  } forEach (keys _old);

  _changed
};

[[_previous, _current, ""] call _walk, _removed]
