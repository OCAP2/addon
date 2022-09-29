/* ----------------------------------------------------------------------------
Script: FUNC(aceThrowing)

Description:
  Adds a local CBA event listener on units that will trigger when a projectile is thrown using ACE Advanced Throwing and add markers to playback that trace its path. Added to units in <FUNC(addUnitEventHandlers)>.

Parameters:
  None

Returns:
  Nothing

Examples:
  --- Code
  FUNC(aceThrowing) remoteExec ["call", _entity];
  ---

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

EGVAR(listener,aceThrowing) = ["ace_throwableThrown", {

  if (!SHOULDSAVEEVENTS) exitWith {};

  params["_unit", "_projectile"];

  if (isNull _projectile) then {
    _projectile = nearestObject [_unit, "CA_Magazine"];
  };

  // systemChat str _this;

  // note that thrown objects outside of ACE explosives do not include a "default magazine" property in their config.
  // this script will attempt to find a matching classname in CfgMagazines, as some chemlights and smokes are built this way.
  // if not found, a default magazine value will be assigned (m67 frag, white smoke, green chemlight)

  _projType = typeOf _projectile;
  _projConfig = configOf _projectile;
  _projName = getText(configFile >> "CfgAmmo" >> _projType >> "displayName");

  // systemChat format["Config name: %1", configOf _projectile];

  _ammoSimType = getText(configFile >> "CfgAmmo" >> _projType >> "simulation");
  // systemChat format["Projectile type: %1", _ammoSimType];

  _markerType = "";
  _markColor = "";
  _magDisp = "";
  _magPic = "";

  _magType = getText(_projConfig >> "defaultMagazine");
  if (_magType == "") then {
    _magType = configName(configfile >> "CfgMagazines" >> _projType)
  };

  if (!(_magType isEqualTo "")) then {
    // systemChat format["Mag type: %1", _magType];

    _magDisp = getText(configFile >> "CfgMagazines" >> _magType >> "displayNameShort");
    if (_magDisp == "") then {
      _magDisp = getText(configFile >> "CfgMagazines" >> _magType >> "displayName")
    };
    if (_magDisp == "") then {
      _magDisp = _projName;
    };

    _magPic = (getText(configfile >> "CfgMagazines" >> _magType >> "picture"));
    // hint parseText format["Projectile fired:<br/><img image='%1'/>", _magPic];
    if (_magPic == "") then {
      _markerType = "mil_triangle";
      _markColor = "ColorRed";
    } else {
      _magPicSplit = _magPic splitString "\";
      _magPic = _magPicSplit#((count _magPicSplit) - 1);
      _markerType = format["magIcons/%1", _magPic];
      _markColor = "ColorWhite";
    };
  } else {
    _markerType = "mil_triangle";
    _markColor = "ColorRed";
    // set defaults based on ammo sim type, if no magazine could be matched
    switch (_ammoSimType) do {
      case "shotGrenade":{
          _magPic = "\A3\Weapons_F\Data\UI\gear_M67_CA.paa";
          _magDisp = "Frag";
        };
      case "shotSmokeX":{
          _magPic = "\A3\Weapons_f\data\ui\gear_smokegrenade_white_ca.paa";
          _magDisp = "Smoke";
        };
      case "shotIlluminating":{
          _magPic = "\A3\Weapons_F\Data\UI\gear_flare_white_ca.paa";
          _magDisp = "Flare";
        };
      default {
        _magPic = "\A3\Weapons_F\Data\UI\gear_M67_CA.paa";
        _magDisp = "Frag";
      };
    };
    // hint parseText format["Projectile fired:<br/><img image='%1'/>", _magPic];
    _magPicSplit = _magPic splitString "\";
    _magPic = _magPicSplit#((count _magPicSplit) - 1);
    _markerType = format["magIcons/%1", _magPic];
    _markColor = "ColorWhite";
  };

  _int = random 2000;

  _markTextLocal = format["%1", _magDisp];
  _markName = format["Projectile#%1", _int];

  // MAKE MARKER FOR PLAYBACK
  _throwerPos = getPosASL _unit;
  [QGVARMAIN(handleMarker), ["CREATED", _markName, _unit, _throwerPos, _markerType, "ICON", [1,1], 0, "Solid", _markColor, 1, _markTextLocal, true]] call CBA_fnc_serverEvent;

  GVAR(liveGrenades) pushBack [_projectile, _magazine, _unit, getPosASL _projectile, _markName, _markTextLocal, _ammoSimType];

  if (GVARMAIN(isDebug)) then {
    // add to map draw array
    private _debugArr = [_projectile, _magPic, format["%1 %2 - %3", str side group _unit, name _unit, _markTextLocal], [side group _unit] call BIS_fnc_sideColor];
    GVAR(liveDebugMagIcons) pushBack _debugArr;
    publicVariable QGVAR(liveDebugMagIcons);
  };
}] call CBA_fnc_addEventHandler;
