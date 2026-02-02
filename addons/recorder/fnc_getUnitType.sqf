/* ----------------------------------------------------------------------------
FILE: fnc_getUnitType.sqf

FUNCTION: OCAP_recorder_fnc_getUnitType

Description:
  Identifies the role of a unit using similar methodology to Arma 3's. Used in <FUNC(captureLoop)>.

Parameters:
  _unitToCheck - Unit to evaluate. [Object]

Returns:
  The role text. [String]

Examples:
  > [_x] call ocap_fnc_getUnitType;

Public:
  No

Author:
  IndigoFox, veteran29
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_unitToCheck"];

private _role = "Man";
private _typePic = getText (configOf _unitToCheck >> "icon");


switch (true) do {
  case (
    ["Officer", _typePic] call BIS_fnc_inString
  ): {_role = "Officer"};
  case (
    _unitToCheck == leader group _unitToCheck
  ): {_role = "Leader"};
};

if (_role == "Man") then {
  switch (true) do {
    case (_unitToCheck getUnitTrait 'medic'): {
      _role = 'Medic';
    };
    case (_unitToCheck getUnitTrait 'engineer'): {
      _role = 'Engineer';
    };
    case (_unitToCheck getUnitTrait 'explosiveSpecialist'): {
      _role = 'ExplosiveSpecialist';
    };
  };
};

if (_role == "Man") then {
  private _weaponPicture = toLower getText (configFile >> "CfgWeapons" >> secondaryWeapon _unitToCheck >> "UiPicture");
  switch (true) do {
    case ("_mg_" in _weaponPicture): {_role = "MG"};
    case ("_gl_" in _weaponPicture): {_role = "GL"};
    case ("_at_" in _weaponPicture): {_role = "AT"};
    case ("_sniper_" in _weaponPicture): {_role = "Sniper"};
    case ("_aa_" in _weaponPicture): {_role = "AA"};
  };
};

if (_role == "Man") then {
  private _weaponPicture = toLower getText (configFile >> "CfgWeapons" >> primaryWeapon _unitToCheck >> "UiPicture");
  switch (true) do {
    case ("_mg_" in _weaponPicture): {_role = "MG"};
    case ("_gl_" in _weaponPicture): {_role = "GL"};
    case ("_at_" in _weaponPicture): {_role = "AT"};
    case ("_sniper_" in _weaponPicture): {_role = "Sniper"};
    case ("_aa_" in _weaponPicture): {_role = "AA"};
  };
};

_role
