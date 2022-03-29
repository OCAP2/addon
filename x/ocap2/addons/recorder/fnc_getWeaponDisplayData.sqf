params ["_weapon", "_muzzle", "_magazine", "_ammo"];

_muzzleDisp = getText(configFile >> "CfgWeapons" >> _weapon >> _muzzle >> "displayName");
if (_muzzleDisp == "") then {_muzzleDisp = getText(configFile >> "CfgWeapons" >> _weapon >> "displayNameShort")};
if (_muzzleDisp == "") then {_muzzleDisp = getText(configFile >> "CfgWeapons" >> _weapon >> "displayName")};
_magDisp = getText(configFile >> "CfgMagazines" >> _magazine >> "displayNameShort");
if (_magDisp == "") then {_magDisp = getText(configFile >> "CfgMagazines" >> _magazine >> "displayName")};
if (_magDisp == "" && !isNil "_ammo") then {_magDisp = getText(configFile >> "CfgAmmo" >> _ammo >> "displayNameShort")};
if (_magDisp == "" && !isNil "_ammo") then {_magDisp = getText(configFile >> "CfgAmmo" >> _ammo >> "displayName")};

[_muzzleDisp, _magDisp];
