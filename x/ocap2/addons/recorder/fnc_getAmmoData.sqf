params ["_firer", "_weapon", "_muzzle", "_mode", "_ammo", "_magazine", "_projectile", "_vehicle"];

_int = random 2000;
_muzzleDisp = getText(configFile >> "CfgWeapons" >> _weapon >> _muzzle >> "displayName");
if (_muzzleDisp == "") then {_muzzleDisp = getText(configFile >> "CfgWeapons" >> _weapon >> "displayNameShort")};
if (_muzzleDisp == "") then {_muzzleDisp = getText(configFile >> "CfgWeapons" >> _weapon >> "displayName")};
_magDisp = getText(configFile >> "CfgMagazines" >> _magazine >> "displayNameShort");
if (_magDisp == "") then {_magDisp = getText(configFile >> "CfgMagazines" >> _magazine >> "displayName")};
if (_magDisp == "") then {_magDisp = getText(configFile >> "CfgAmmo" >> _ammo >> "displayNameShort")};
if (_magDisp == "") then {_magDisp = getText(configFile >> "CfgAmmo" >> _ammo >> "displayName")};

// non-bullet handling
private ["_markTextLocal"];
if (!isNull _vehicle) then {
  _markTextLocal = format["[%3] %1 - %2", _muzzleDisp, _magDisp, ([configOf _vehicle] call BIS_fnc_displayName)];
} else {
  if (_ammoSimType isEqualTo "shotGrenade") then {
    _markTextLocal = format["%1", _magDisp];
  } else {
    _markTextLocal = format["%1 - %2", _muzzleDisp, _magDisp];
  };
};

_markName = format["Projectile#%1", _int];
_markColor = "ColorRed";
_markerType = "";
_magPic = (getText(configfile >> "CfgMagazines" >> _magazine >> "picture"));
if (_magPic == "") then {
  _markerType = "mil_triangle";
} else {
  _magPicSplit = _magPic splitString "\";
  _magPic = _magPicSplit # ((count _magPicSplit) -1);
  _markerType = format["magIcons/%1", _magPic];
  _markColor = "ColorWhite";
};

[_markTextLocal,_markName,_markColor,_markerType];


  // _markStr = format["|%1|%2|%3|%4|%5|%6|%7|%8|%9|%10",
  // 	_markName,
  // 	getPos _firer,
  // 	"mil_triangle",
  // 	"ICON",
  // 	[1, 1],
  // 	0,
  // 	"Solid",
  // 	"ColorRed",
  // 	1,
  // 	_markTextLocal
  // ];

  // _markStr call BIS_fnc_stringToMarkerLocal;

  // diag_log text format["detected grenade, created marker %1", _markStr];

  // _markStr = str _mark;
  // _mark = createMarkerLocal [format["Projectile%1", _int],_projectile];
  // _mark setMarkerColorLocal "ColorRed";
  // _mark setMarkerTypeLocal "selector_selectable";
  // _mark setMarkerShapeLocal "ICON";
  // _mark setMarkerTextLocal format["%1 - %2", _firer, _markTextLocal];
