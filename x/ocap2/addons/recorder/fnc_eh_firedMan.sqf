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

private _initialProjPos = getPos _projectile;
if (getPos _firer distance _initialProjPos > 50 || vehicle _firer isKindOf "Air") then {
  // if projectile in unscheduled environment is > 50m from FiredMan then likely remote controlled
  // we should find the actual firing entity
  private _nearest = [_initialProjPos, allUnits select {!isPlayer _x}, 75] call CBA_fnc_getNearest;
  if (count _nearest > 0) then {
    _firer = _nearest#0;
  };
};

// missionNamespace getVariable ["bis_fnc_moduleRemoteControl_unit", _firer];
// _unit getVariable ["BIS_fnc_moduleRemoteControl_owner", objNull];

// not sent in ACE Throwing events
if (isNil "_vehicle") then {_vehicle = objNull};
if (!isNull _vehicle) then {
  _projectile setShotParents [_vehicle, _firer];
} else {
  _projectile setShotParents [_firer, _firer];
};

private _frame = GVAR(captureFrameNo);

private _firerId = (_firer getVariable [QGVARMAIN(id), -1]);
if (_firerId == -1) exitWith {};

// set the firer's lastFired var as this weapon, so subsequent kills are logged accurately
([_weapon, _muzzle, _magazine, _ammo] call FUNC(getWeaponDisplayData)) params ["_muzzleDisp", "_magDisp"];

private _wepString = "";
if (_muzzleDisp find _magDisp == -1 && _magDisp isNotEqualTo "") then {
  _wepString = format["%1 [%2]", _muzzleDisp, _magDisp];
} else {
  _wepString = _muzzleDisp;
};
if (!isNull _vehicle) then {
  _wepString = format["%1 [%2]", (configOf _vehicle) call BIS_fnc_displayName, _wepString];
};
_firer setVariable [QGVARMAIN(lastFired), _wepString];
(vehicle _firer) setVariable [QGVARMAIN(lastFired), _wepString];

_ammoSimType = getText(configFile >> "CfgAmmo" >> _ammo >> "simulation");
// _ammoSimType
// "ShotGrenade" // M67
// "ShotRocket" // S-8
// "ShotMissile" // R-27
// "ShotShell" // VOG-17M, HE40mm
// "ShotMine" // Satchel charge
// "ShotIlluminating" // 40mm_green Flare
// "ShotSmokeX"; // M18 Smoke

#define LOGBULLET GVAR(liveBullets) pushBack [_projectile, _firerId, _firer, getPosASL _projectile]
#define LOGMISSILE GVAR(liveMissiles) pushBack [_projectile, _wepString, _firer, getPosASL _projectile, _markName, _markTextLocal]
#define LOGGRENADE GVAR(liveGrenades) pushBack [_projectile, _wepString, _firer, getPosASL _projectile, _markName, _markTextLocal, _ammoSimType];

switch (true) do {
  case (_ammoSimType isEqualTo "shotBullet"): {
    // [_projectile, _firer, _frame, _ammoSimType, _ammo] spawn {
    //   params["_projectile", "_firer", "_frame", "_ammoSimType", "_ammo"];
    if (isNull _projectile) then {
      _projectile = nearestObject [_firer, _ammo];
    };
    if (isNil "_projectile") exitWith {};
    LOGBULLET;
  };


  case (_ammoSimType isNotEqualTo "shotSubmunitions"): {

    if (isNull _projectile) then {
      _projectile = nearestObject [_firer, _ammo];
      _this set [6, _projectile];
    };

    ([_weapon, _muzzle, _ammo, _magazine, _projectile, _vehicle, _ammoSimType] call FUNC(getAmmoMarkerData)) params ["_markTextLocal","_markName","_markColor","_markerType"];
    private _magIcon = getText(configFile >> "CfgMagazines" >> _magazine >> "picture");

    // MAKE MARKER FOR PLAYBACK
    _firerPos = getPosASL _firer;
    [QGVARMAIN(handleMarker), ["CREATED", _markName, _firer, _firerPos, _markerType, "ICON", [1,1], getDirVisual _firer, "Solid", _markColor, 1, _markTextLocal, true]] call CBA_fnc_localEvent;

    switch (true) do {
      case (_ammoSimType in ["shotMissile", "shotRocket", "shotShell"]): {
        LOGMISSILE;

        if (GVARMAIN(isDebug)) then {
          // add to map draw array
          private _debugArr = [_projectile, _magIcon, format["%1 %2 - %3", str side group _firer, name _firer, _markTextLocal], [side group _firer] call BIS_fnc_sideColor];
          [QGVAR(addDebugMagIcon), _debugArr] call CBA_fnc_globalEvent;
        };
      };
      case (_ammoSimType in ["shotGrenade", "shotIlluminating", "shotMine", "shotSmokeX", "shotCM"]): {
        LOGGRENADE;

        if (GVARMAIN(isDebug)) then {
          // add to map draw array
          private _debugArr = [_projectile, _magIcon, format["%1 %2 - %3", str side group _firer, name _firer, _markTextLocal], [side group _firer] call BIS_fnc_sideColor];
          [QGVAR(addDebugMagIcon), _debugArr] call CBA_fnc_globalEvent;
        };
      };
      default {OCAPEXTLOG(ARR3("Invalid ammo sim type, check it", _projectile, _ammoSimType))};
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
    private _subTypesAmmoSimType = _subTypes apply {(configFile >> "CfgAmmo" >> _x >> "simulation") call BIS_fnc_getCfgData};
    if (count _subTypesAmmoSimType > 0) then {
      _subTypesAmmoSimType = selectRandom(_subTypesAmmoSimType);
    };
    [
      {
        _this spawn {
          params ["_EHData", "_subTypes", "_magazine", "_wepString", "_firer", "_firerId", "_firerPos", "_frame", "_ammoSimType", "_subTypesAmmoSimType"];
          // private _projectile = _EHData # 6;

          // if submunitions are NOT bullets, wait until the original projectile deploys then search for submunitions and 're-fire' them to appear in playback
          // if !(_subTypesAmmoSimType == "shotBullet") exitWith {
          // if (_magazine isKindOf "VehicleMagazine") then {
          //   [_EHData, _projectile, _subTypes] spawn {
          //     params ["_EHData", "_projectile", "_subTypes"];
          //     private _ogPos = getPos _firer;
          //     while {!isNull _projectile} do {_ogPos = getPosASL _projectile; sleep 0.1;};
          //     isNil {
          //       _projSearch = nearestObjects [ASLtoAGL _ogPos, _subTypes, 50, false];
          //       {
          //         _EHData set [6, _x];
          //         _EHData spawn FUNC(eh_firedMan);
          //       } forEach _projSearch;
          //     };
          //   };
          // };

          // if submunitions ARE bullets, process normally and just look for one item
          _EHData params ["_firer", "_weapon", "_muzzle", "_mode", "_ammo", "_magazine", "_projectile", "_vehicle"];
          private _projectile = objNull;
          // while {isNull _projectile} do {
          //   {
          //     _projSearch = nearestObject [_firer, _x];
          //     if !(isNull _projSearch) exitWith {_projectile = _projSearch};
          //   } forEach _subTypes;
          // };

          while {isNull _projectile} do {
            {
              _projSearch = nearestObject [_firer, _x];
              if !(isNull _projSearch) exitWith {_projectile = _projSearch};
            } forEach _subTypes;
          };
          _newSubs = nearestObjects [_projectile, _subTypes, 50];


          isNil {
            {
              private _projectile = _x;

              // get marker details based on original EH data
              ([_weapon, _muzzle, _ammo, _magazine, _projectile, _vehicle, _ammoSimType] call FUNC(getAmmoMarkerData)) params ["_markTextLocal","_markName","_markColor","_markerType"];
              private _magIcon = getText(configFile >> "CfgMagazines" >> _magazine >> "picture");

              // then get data of submunition to determine how to track it
              private _ammoSimType = getText(configFile >> "CfgAmmo" >> (typeOf _projectile) >> "simulation");
              switch (true) do {
                case (_ammoSimType isEqualTo "shotBullet"): {
                  LOGBULLET;
                };
                case (_ammoSimType in ["shotMissile", "shotRocket", "shotShell"]): {
                  LOGMISSILE;

                  // create our marker record in the timeline
                  [QGVARMAIN(handleMarker), ["CREATED", _markName, _firer, getPosASL _firer, _markerType, "ICON", [1,1], getDir _firer, "Solid", _markColor, 1, _markTextLocal, true]] call CBA_fnc_localEvent;

                  if (GVARMAIN(isDebug)) then {
                    // add to clients' map draw array
                    private _debugArr = [_projectile, _magIcon, format["%1 %2 - %3", str side group _firer, name _firer, _markTextLocal], [side group _firer] call BIS_fnc_sideColor];
                    [QGVAR(addDebugMagIcon), _debugArr] call CBA_fnc_globalEvent;
                  };
                };
                case (_ammoSimType in ["shotGrenade", "shotIlluminating", "shotMine", "shotSmokeX", "shotCM"]): {
                  LOGGRENADE;

                  // create our marker record in the timeline
                  [QGVARMAIN(handleMarker), ["CREATED", _markName, _firer, getPosASL _firer, _markerType, "ICON", [1,1], getDir _firer, "Solid", _markColor, 1, _markTextLocal, true]] call CBA_fnc_localEvent;

                  if (GVARMAIN(isDebug)) then {
                    // add to map draw array
                    private _debugArr = [_projectile, _magIcon, format["%1 %2 - %3", str side group _firer, name _firer, _markTextLocal], [side group _firer] call BIS_fnc_sideColor];
                    [QGVAR(addDebugMagIcon), _debugArr] call CBA_fnc_globalEvent;
                  };
                };
                default {OCAPEXTLOG(ARR3("Invalid ammo sim type, check it", _projectile, _ammoSimType))};
              };
            } forEach _newSubs;
            nil;
          };
        };
      },
      [_this, _subTypes, _magazine, _wepString, _firer, _firerId, _firerPos, _frame, _ammoSimType, _subTypesAmmoSimType],
      _simDelay
    ] call CBA_fnc_waitAndExecute;
  };
};
