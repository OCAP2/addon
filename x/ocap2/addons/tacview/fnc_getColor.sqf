#include "script_component.hpp"

params ["_object"];

_color = GVAR(sideToColorCache) getOrDefault [side (group _object), "Violet"];

if ((_object call BIS_fnc_objectType) # 0 == "Soldier") then {
  _color = GVAR(sideToColorCache) getOrDefault [side (group _object), "Violet"];
  if (EGVAR(settings,preferACEUnconscious) && !isNil "ace_common_fnc_isAwake") then {
    if !([_object] call ace_common_fnc_isAwake) then {_color = "Orange"};
  } else {
    if (lifeState _object isEqualTo "INCAPACITATED") then {_color = "Orange"};
  };
  if (!alive _object) then {_color = "Yellow"};
} else {
  _color = GVAR(sideToColorCache) getOrDefault [[_object] call BIS_fnc_objectSide, "Cyan"];
};

_color;
