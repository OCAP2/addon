/* ----------------------------------------------------------------------------
FILE: fnc_getWeaponDisplayData.sqf

FUNCTION: OCAP_recorder_fnc_getWeaponDisplayData

Description:
  Used to populate <OCAP_lastFired> on units in <OCAP_recorder_fnc_eh_firedMan>.

Parameters:
  _weapon - Weapon class name [String]
  _muzzle - Muzzle class name [String]
  _magazine - Magazine class name [String]
  _ammo - Ammo class name [String]

Returns:
  [Array]

    0 - Muzzle display name [String]
    1 - Magazine display name [String]

Examples:
  > ([_weapon, _muzzle, _magazine, _ammo] call FUNC(getWeaponDisplayData)) params ["_muzzleDisp", "_magDisp"];

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
params ["_weapon", "_muzzle", "_magazine", "_ammo"];

_muzzleDisp = getText(configFile >> "CfgWeapons" >> _weapon >> _muzzle >> "displayName");
if (_muzzleDisp == "") then {_muzzleDisp = getText(configFile >> "CfgWeapons" >> _weapon >> "displayNameShort")};
if (_muzzleDisp == "") then {_muzzleDisp = getText(configFile >> "CfgWeapons" >> _weapon >> "displayName")};
_magDisp = getText(configFile >> "CfgMagazines" >> _magazine >> "displayNameShort");
if (_magDisp == "") then {_magDisp = getText(configFile >> "CfgMagazines" >> _magazine >> "displayName")};
if (_magDisp == "" && !isNil "_ammo") then {_magDisp = getText(configFile >> "CfgAmmo" >> _ammo >> "displayNameShort")};
if (_magDisp == "" && !isNil "_ammo") then {_magDisp = getText(configFile >> "CfgAmmo" >> _ammo >> "displayName")};

if (_muzzleDisp find _magDisp > -1 && _magDisp isNotEqualTo "") then {
  _muzzleDisp = getText(configFile >> "CfgWeapons" >> _weapon >> "displayName");
};

[_muzzleDisp, _magDisp];
