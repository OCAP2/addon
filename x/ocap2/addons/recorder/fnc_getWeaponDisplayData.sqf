#include "script_component.hpp"

params ["_weapon", "_muzzle", "_magazine", "_ammo"];

_key = _this joinString '-';
_array = GVAR(weaponDisplayDataCache) get _key;

if (isNil "_array") then {
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

  _array = [_muzzleDisp, _magDisp];
  GVAR(weaponDisplayDataCache) set [_key, _array];
};

_array
