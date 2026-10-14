/* ----------------------------------------------------------------------------
FILE: fnc_encodeJSON.sqf

FUNCTION: OCAP_recorder_fnc_encodeJSON

Description:
  Serializes a payload to JSON for the general-event message field. A drop-in
  for CBA_fnc_encodeJSON on the shapes our events use, at a fraction of the cost.

  CBA_fnc_encodeJSON escapes every string with eight CBA_fnc_replace calls, each
  a scripted find/concat loop. A full inventory snapshot carries about 300
  strings, so one encode ran some 2,500 scripted calls and cost several server
  frames in one go -- and every player sends one at the start of a recording,
  on every keyframe and on every join. Strings are escaped here with the
  engine's own `toJSON`, one native call each.

  Numbers and booleans still go through `str`, exactly as CBA writes them, so the
  values that reach the recording are unchanged. `toJSON` is not used for them
  because its float formatting is undocumented; `str` is the six-significant-
  digit form every recording so far was written with. The extension and the
  exporter both parse the result with a real JSON decoder, so the separators
  CBA put spaces after carry no meaning and are left out.

  HashMaps and arrays are walked in script. Leaves -- the vast majority of the
  values -- are handled inline instead of through another call. Anything this
  does not know (an object, a namespace, a CBA hash) is handed to
  CBA_fnc_encodeJSON, so no input encodes differently from before.

Parameters:
  _value - Value to serialize. [HashMap, Array, String, Number, Boolean or nil]

Returns:
  JSON text. [String]

Examples:
  > [createHashMapFromArray [["fps", diag_fps]]] call FUNC(encodeJSON);

Public:
  No

Author:
  OCAP Improved
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_value"];

private _encode = {
  params ["_value"];
  if (isNil "_value") exitWith {"null"};

  switch (true) do {
    case (_value isEqualType ""): {toJSON _value};
    case (_value isEqualTypeAny [0, true]): {str _value};
    case (_value isEqualType createHashMap): {
      "{" + (((_value toArray false) apply {
        _x params ["_key", "_item"];
        if !(_key isEqualType "") then {_key = str _key};
        (toJSON _key) + ":" + (
          if (isNil "_item") then {"null"} else {
            if (_item isEqualType "") then {toJSON _item} else {
              if (_item isEqualTypeAny [0, true]) then {str _item} else {[_item] call _encode}
            }
          }
        )
      }) joinString ",") + "}"
    };
    // CBA_fnc_isHash, inlined: a legacy CBA hash is a four-element array tagged
    // in slot 0, and CBA encodes it as an object, so it is left to CBA.
    case (_value isEqualType [] && {count _value != 4 || {(_value select 0) isNotEqualTo "#CBA_HASH#"}}): {
      "[" + ((_value apply {
        if (isNil "_x") then {"null"} else {
          if (_x isEqualType "") then {toJSON _x} else {
            if (_x isEqualTypeAny [0, true]) then {str _x} else {[_x] call _encode}
          }
        }
      }) joinString ",") + "]"
    };
    default {[_value] call CBA_fnc_encodeJSON};
  };
};

[_value] call _encode
