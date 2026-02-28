/* ----------------------------------------------------------------------------
FILE: fnc_getClass.sqf

FUNCTION: OCAP_recorder_fnc_getClass

Description:
  Determines what type of vehicle is being recorded to match with the more limited icon set preloaded in the OCAP playback UI.

Parameters:
  _this - The vehicle being queried [Object]

Returns:
  [String] - The icon name that should be used to represent the vehicle in the playback UI

Examples:
  > _class = _vehType call FUNC(getClass);

Public:
  No

Author:
  Zealot, Dell
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (isNil QGVAR(classCache)) then {
  GVAR(classCache) = createHashMap;
};

private _cached = GVAR(classCache) getOrDefault [_this, ""];
if (_cached isNotEqualTo "") exitWith {_cached};

private _result = call {
  if (getText(configFile >> "CfgVehicles" >> _this >> "model") isEqualTo "\A3\Weapons_f\empty") exitWith {"unknown"};
  if ((toLower getText(configFile >> "CfgVehicles" >> _this >> "displayName")) find "ejection" > -1) exitWith {"parachute"};
  if (_this isKindOf "Truck_F") exitWith {"truck"};
  if (_this call FUNC(isKindOfApc)) exitWith {"apc"};
  if (_this isKindOf "Car") exitWith {"car"};
  if (_this isKindOf "Tank") exitWith {"tank"};
  if (_this isKindOf "StaticMortar") exitWith {"static-mortar"};
  if (_this isKindOf "StaticWeapon") exitWith {"static-weapon"};
  if (_this isKindOf "ParachuteBase") exitWith {"parachute"};
  if (_this isKindOf "Helicopter") exitWith {"heli"};
  if (_this isKindOf "Plane") exitWith {"plane"};
  if (_this isKindOf "Air") exitWith {"plane"};
  if (_this isKindOf "Ship") exitWith {"sea"};
  "unknown"
};

GVAR(classCache) set [_this, _result];
_result
