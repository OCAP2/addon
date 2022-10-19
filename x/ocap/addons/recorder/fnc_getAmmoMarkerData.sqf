/* ----------------------------------------------------------------------------
FILE: fnc_getAmmoMarkerData.sqf

FUNCTION: OCAP_recorder_fnc_getAmmoMarkerData

Description:
  This function will intake information from <OCAP_EH_FiredMan> and return data used to format a marker for entry into the timeline.

Parameters:
  _weapon - The weapon used [String]
  _muzzle - The muzzle used [String]
  _ammo - The ammo used [String]
  _magazine - The magazine used [String]
  _projectile - The projectile object [Object]
  _vehicle - The vehicle the weapon is mounted on, if any [Object]
  _ammoSimType - The ammo simulation type [String]

Returns:
  [_markTextLocal,_markName,_markColor,_markerType] - The marker data [Array]

Examples:
  > ([_weapon, _muzzle, _ammo, _magazine, _projectile, _vehicle, _ammoSimType] call FUNC(getAmmoMarkerData)) params ["_markTextLocal","_markName","_markColor","_markerType"];

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_weapon", "_muzzle", "_ammo", "_magazine", "_projectile", "_vehicle", "_ammoSimType"];

_int = random 2000;
([_weapon, _muzzle, _magazine, _ammo] call FUNC(getWeaponDisplayData)) params ["_muzzleDisp", "_magDisp"];

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
