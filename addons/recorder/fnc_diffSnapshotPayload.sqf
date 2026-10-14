/* ----------------------------------------------------------------------------
FILE: fnc_diffSnapshotPayload.sqf

FUNCTION: OCAP_recorder_fnc_diffSnapshotPayload

Description:
  Compares two player-snapshot payloads and returns only what changed.

  Nested HashMaps are walked recursively so a single changed vital does not drag
  the whole medical block along.

  An array whose entries are HashMaps carrying a unique identifier ("class" for
  gear, "slot" for weapons, "part" for body parts) is patched entry by entry:

  > {"$key": "class", "put": [{"class": "30Rnd_556", "totalRounds": 149}], "del": ["Chemlight_green"]}

  Without that, a single round leaving one magazine rewrote every magazine the
  player carried, which was the largest single cost in a recording. Arrays that
  have no such identifier are still replaced whole.

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

// The field that addresses entries in both arrays, or "" when they cannot be
// paired up: an entry that is not a HashMap, a missing identifier, or the same
// identifier twice all rule out an entry-wise patch.
private _arrayKeyField = {
  params ["_old", "_new"];

  if (((_old + _new) findIf {!(_x isEqualType _hashMapType)}) > -1) exitWith {""};

  // Identifiers an entry may be addressed by, in the order they are tried.
  private _field = "";
  {
    private _candidate = _x;
    private _oldKeys = _old apply {_x getOrDefault [_candidate, ""]};
    private _newKeys = _new apply {_x getOrDefault [_candidate, ""]};
    if (((_oldKeys + _newKeys) findIf {!(_x isEqualType "") || {_x isEqualTo ""}}) == -1 &&
      {count (_oldKeys arrayIntersect _oldKeys) == count _oldKeys} &&
      {count (_newKeys arrayIntersect _newKeys) == count _newKeys}) exitWith {
      _field = _candidate;
    };
  } forEach ["class", "slot", "part"];
  _field
};

private _diffKeyedArray = {
  params ["_old", "_new"];

  // Emptying an array, or filling an empty one, is cheaper written out in full.
  if (_old isEqualTo [] || {_new isEqualTo []}) exitWith {nil};

  private _field = [_old, _new] call _arrayKeyField;
  if (_field isEqualTo "") exitWith {nil};

  private _oldByKey = createHashMap;
  {_oldByKey set [_x get _field, _x]} forEach _old;

  private _put = [];
  {
    private _entry = _x;
    private _key = _entry get _field;
    private _base = _oldByKey get _key;
    if (isNil "_base") then {
      _put pushBack _entry;
    } else {
      // Most entries are untouched between two samples (one magazine lost a
      // round, the other twenty did not). A native comparison settles those
      // without walking them key by key.
      if (_entry isEqualTo _base) then {continue};
      private _mark = count _removed;
      private _child = [_base, _entry, ""] call _walk;
      if (count _removed > _mark) then {
        // The entry dropped a field. A dot path cannot address a position inside
        // an array, so the entry is rewritten in full rather than unset.
        _removed resize _mark;
        _put pushBack _entry;
      } else {
        if (count _child > 0) then {
          _child set [_field, _key];
          _put pushBack _child;
        };
      };
    };
  } forEach _new;

  private _newKeys = _new apply {_x get _field};
  private _oldKeys = _old apply {_x get _field};
  private _del = _oldKeys select {!(_x in _newKeys)};

  // Applying put and del alone keeps surviving entries where they were and adds
  // new ones at the end. Where that is not the order sampled, say so: the
  // Arsenal export reads assignedItems positionally, so the order is data.
  private _applied = _oldKeys select {!(_x in _del)};
  {
    private _key = _x get _field;
    if (!(_key in _applied)) then {_applied pushBack _key};
  } forEach _put;
  private _reordered = _applied isNotEqualTo _newKeys;

  if (_put isEqualTo [] && {_del isEqualTo []} && {!_reordered}) exitWith {nil};

  private _patch = createHashMapFromArray [["$key", _field]];
  if (_put isNotEqualTo []) then {_patch set ["put", _put]};
  if (_del isNotEqualTo []) then {_patch set ["del", _del]};
  if (_reordered) then {_patch set ["ord", _newKeys]};

  _patch
};

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
      // Identical values, nested HashMaps included, need no walk at all.
      if (_newValue isEqualTo _oldValue) then {continue};
      if (_newValue isEqualType _hashMapType && {_oldValue isEqualType _hashMapType}) then {
        private _child = [_oldValue, _newValue, _prefix + _key + "."] call _walk;
        if (count _child > 0) then {_changed set [_key, _child]};
      } else {
        if (_newValue isNotEqualTo _oldValue) then {
          private _patch = nil;
          if (_newValue isEqualType [] && {_oldValue isEqualType []}) then {
            _patch = [_oldValue, _newValue] call _diffKeyedArray;
          };
          if (isNil "_patch") then {
            _changed set [_key, _newValue];
          } else {
            _changed set [_key, _patch];
          };
        };
      };
    };
  } forEach _new;

  {
    if (!(_x in _new)) then {_removed pushBack (_prefix + _x)};
  } forEach (keys _old);

  _changed
};

[[_previous, _current, ""] call _walk, _removed]
