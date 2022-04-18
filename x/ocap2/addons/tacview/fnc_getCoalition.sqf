#include "script_component.hpp"

params ["_object"];

_coalition = _object getVariable QGVAR(objectCoalition);

if (isNil "_coalition") then {
  if ((_object call BIS_fnc_objectType) # 0 == "Soldier") then {
    _coalition = GVAR(sideToCoalitionCache) getOrDefault [side (group _object), "OTHER"];
  } else {
    _coalition = GVAR(sideToCoalitionCache) getOrDefault [[_object] call BIS_fnc_objectSide, "OTHER" ];
  };
  _object setVariable [QGVAR(objectCoalition), _coalition];
};

_coalition;
