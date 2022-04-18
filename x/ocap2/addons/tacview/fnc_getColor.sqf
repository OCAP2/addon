#include "script_component.hpp"

params ["_object"];

_color = _object getVariable QGVAR(objectColor);

if (isNil "_color") then {
  if ((_object call BIS_fnc_objectType) # 0 == "Soldier") then {
    _color = GVAR(sideToColorCache) getOrDefault [side (group _object), "Violet"];
  } else {
    _color = GVAR(sideToColorCache) getOrDefault [[_object] call BIS_fnc_objectSide, "Violet" ];
  };
  _object setVariable [QGVAR(objectColor), _color];
};

_color;
