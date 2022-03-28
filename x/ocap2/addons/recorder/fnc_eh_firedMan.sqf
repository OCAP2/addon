/* ----------------------------------------------------------------------------
Script: FUNC(eh_firedMan)

Description:
  Tracks bullet and non-bullet projectiles. This is the code triggered when a unit firing is detected by the "FiredMan" Event Handler applied to units during <FUNC(addUnitEventHandlers)>.

Parameters:
  _firer - Unit the event handler is assigned to (the instigator) [Object]
  _weapon - Fired weapon [String]
  _muzzle - Muzzle that was used [String]
  _mode - Current mode of the fired weapon [String]
  _ammo - Ammo used [String]
  _magazine - Magazine name which was used [String]
  _projectile - Object of the projectile that was shot out [Object]
  _vehicle - if weapon is vehicle weapon, otherwise objNull [Object]

Returns:
  Nothing

Examples:
  --- Code
  ---

Public:
  No

Author:
  IndigoFox, Dell
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {};

params ["_firer", "_weapon", "_muzzle", "_mode", "_ammo", "_magazine", "_projectile", "_vehicle"];

private _frame = GVAR(captureFrameNo);

private _firerId = (_firer getVariable [QGVARMAIN(id), -1]);
if (_firerId == -1) exitWith {};

// set the firer's lastFired var as this weapon, so subsequent kills are logged accurately
isNil {
  _firer setVariable [
    QGVARMAIN(lastFired),
    format[
      "%1 [%2]",
      getText (configFile >> "CfgWeapons" >> _weapon >> "displayName"),
      getText (configFile >> "CfgWeapons" >> _muzzle >> "displayName")
    ]
  ];
};

_ammoSimType = getText(configFile >> "CfgAmmo" >> _ammo >> "simulation");
// _ammoSimType
// "ShotGrenade" // M67
// "ShotRocket" // S-8
// "ShotMissile" // R-27
// "ShotShell" // VOG-17M, HE40mm
// "ShotMine" // Satchel charge
// "ShotIlluminating" // 40mm_green Flare
// "ShotSmokeX"; // M18 Smoke


switch (_ammoSimType) do {
  case (_ammoSimType isEqualTo "shotBullet"): {
    // [_projectile, _firer, _frame, _ammoSimType, _ammo] spawn {
    //   params["_projectile", "_firer", "_frame", "_ammoSimType", "_ammo"];
    if (isNull _projectile) then {
      _projectile = nearestObject [_firer, _ammo];
    };
    GVAR(liveBullets) pushBack [_projectile, _firerId, _frame, getPosASL _projectile];
  };


  case (_ammoSimType isNotEqualTo "shotSubmunitions"): {

    // MAKE MARKER FOR PLAYBACK
    _firerPos = getPosASL _firer;
    [QGVARMAIN(handleMarker), ["CREATED", _markName, _firer, _firerPos, _markerType, "ICON", [1,1], getDirVisual _firer, "Solid", _markColor, 1, _markTextLocal, true]] call CBA_fnc_localEvent;

    if (isNull _projectile) then {
      _projectile = nearestObject [_firer, _ammo];
    };

    switch (true) do {
      case (_ammoSimType isEqualTo "shotBullet"): {
        GVAR(liveBullets) pushBack [_projectile, _firerId, _frame, getPosASL _projectile];
      };
      case (_ammoSimType in ["shotMissile", "shotRocket", "shotShell"]): {
        GVAR(liveMissiles) pushBack [_projectile, _magazine, _firer, getPosASL _projectile, _markName];
      };
      case (_ammoSimType in ["shotGrenade", "shotIlluminating", "shotMine", "shotSmokeX"]): {
        GVAR(liveGrenades) pushBack [_projectile, _magazine, _firer, getPosASL _projectile, _markName, _ammoSimType];
      };
      default {OCAPEXTLOG(ARR3("Invalid ammo sim type, check it", _projectile, _newAmmoSimType))};
    };
  };


  case (_ammoSimType isEqualTo "shotSubmunitions"): {

    // for submunitions, we first look at the original ammo and find the classnames of submunition ammo its rounds will turn into
    // these are done in a staggered array in format ["classname1", probability of spawn, "classname2", probability of spawn]
    // this is usually for vehicles with guns that fire mixed ammo, or for cluster munitions
    // we'll wait for the simStep to have elapsed, then start checking for the resulting submunition nearby
    // once we have that, we'll add it to the bullet tracking array for positions so a fireline is drawn in playback
    private _simDelay = (configFile >> "CfgAmmo" >> _ammo >> "simulationStep") call BIS_fnc_getCfgData;
    private _subTypes = ((configFile >> "CfgAmmo" >> _ammo >> "submunitionAmmo") call BIS_fnc_getCfgDataArray) select {_x isEqualType ""};
    [{
      params ["_EHData", "_subTypes", "_magazine", "_firer", "_firerId", "_firerPos", "_frame"];
      private _projectile = objNull;
      while {isNull _projectile} do {
        {
          _projSearch = nearestObject [_firer, _x];
          if !(isNull _projSearch) exitWith {_projectile = _projSearch};
        } forEach _subTypes;
      };

      // get marker details based on original EH data
      (_EHData call FUNC(getAmmoData)) params ["_markTextLocal","_markName","_markColor","_markerType"];
      // create our marker record in the timeline
      [QGVARMAIN(handleMarker), ["CREATED", _markName, _firer, getPosASL _firer, _markerType, "ICON", [1,1], getDir _firer, "Solid", _markColor, 1, _markTextLocal, true]] call CBA_fnc_localEvent;

      private _newAmmoSimType = getText(configFile >> "CfgAmmo" >> _projectile >> "simulation");
      switch (true) do {
        case (_newAmmoSimType isEqualTo "shotBullet"): {
          GVAR(liveBullets) pushBack [_projectile, _firerId, _frame, getPosASL _projectile];
        };
        case (_newAmmoSimType in ["shotMissile", "shotRocket", "shotShell"]): {
          GVAR(liveMissiles) pushBack [_projectile, _magazine, _firer, getPosASL _projectile, _markName];
        };
        case (_newAmmoSimType in ["shotGrenade", "shotIlluminating", "shotMine", "shotSmokeX"]): {
          GVAR(liveGrenades) pushBack [_projectile, _magazine, _firer, getPosASL _projectile, _markName, _newAmmoSimType];
        };
        default {OCAPEXTLOG(ARR3("Invalid ammo sim type, check it", _projectile, _newAmmoSimType))};
      };
    }, [_this, _subTypes, _magazine, _firer, _firerId, _firerPos, _frame], _simDelay] call CBA_fnc_waitAndExecute;
  };
};
