#include "script_component.hpp"

if (_this isKindOf "Truck_F") exitWith {"truck"}; // Should be higher than Car
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
