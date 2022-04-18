#include "script_component.hpp"
params ["_object"];
if (isNull _object) exitWith {""};
if (isPlayer _object) then { name _object } else { _object };
