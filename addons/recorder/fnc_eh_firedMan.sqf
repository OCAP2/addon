/* ----------------------------------------------------------------------------
	FILE: fnc_eh_firedMan.sqf

	FUNCTION: OCAP_recorder_fnc_eh_firedMan

	Description:
	  Tracks bullet and non-bullet projectiles. This is the code triggered when a unit firing is detected by the "FiredMan" Event Handler applied to units during <OCAP_recorder_fnc_addUnitEventHandlers>.

	Parameters:
	  _firer - Unit the event handler is assigned to (the instigator) [Object]
	  _weapon - Fired weapon [String]
	  _muzzle - Muzzle that was used [String]
	  _mode - Current mode of the fired weapon [String]
	  _ammo - className of ammo used [String]
	  _magazine - className of magazine used [String]
	  _projectile - Object of the projectile that was shot out [Object]
	  _vehicle - if weapon is vehicle weapon, otherwise objNull [Object]

	Returns:
	  Nothing

	Examples:
	  > [_firer, _weapon, _muzzle, _mode, _ammo, _magazine, _projectile, _vehicle] call FUNC(eh_firedMan);

	Public:
	  No

	Author:
	  IndigoFox, Dell

---------------------------------------------------------------------------- */

/*
	  Variable: OCAP_lastFired
	  Indicates a structured array [vehicleName, weaponDisp, magDisp] of the last weapon fired by the unit. Used for logging kills. Applied to a firing unit.
*/

/*
	  Event Handlers: Projectiles (Non-Bullets)
	  Deleted - Triggered when a non-bullet projectile is deleted. Updates marker position, then removes it 3 frames later.
	  Explode - Triggered when a non-bullet projectile explodes. Updates marker position, then removes it 3 frames later.
*/

/*
	  CBA Events: Projectiles
	  OCAP_recorder_addDebugMagIcon - Triggered when a non-bullet projectile is fired and the debug mode is enabled. Shares recent data to all clients.
*/

#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {};

params ["_firer", "_weapon", "_muzzle", "_mode", "_ammo", "_magazine", "_projectile", "_vehicle"];

private _initialProjPos = getPosASL _projectile;
if (getPos _firer distance _initialProjPos > 50 || vehicle _firer isKindOf "Air") then {
	// if projectile in unscheduled environment is > 50m from FiredMan then likely remote controlled
	  // we should find the actual firing entity
	private _nearest = [_initialProjPos, allUnits select {
		!isPlayer _x
	}, 75] call CBA_fnc_getNearest;
	if (count _nearest > 0) then {
		_firer = _nearest#0;
	};
};

// missionNamespace getVariable ["bis_fnc_moduleRemoteControl_unit", _firer];
// _unit getVariable ["BIS_fnc_moduleRemoteControl_owner", objNull];

// not sent in ACE Throwing events
if (isNil "_vehicle") then {
	_vehicle = objNull
};
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

private _wepString = [];
if (!isNull _vehicle) then {
	_wepString = [([configOf _vehicle] call BIS_fnc_displayName), _muzzleDisp, _magDisp];
} else {
	_wepString = ["", _muzzleDisp, _magDisp];
};

_firer setVariable [QGVARMAIN(lastFired), _wepString];
(vehicle _firer) setVariable [QGVARMAIN(lastFired), _wepString];

// _ammoSimType
// "ShotGrenade" // M67
// "ShotRocket" // S-8
// "ShotMissile" // R-27
// "ShotShell" // VOG-17M, HE40mm
// "ShotMine" // Satchel charge
// "ShotIlluminating" // 40mm_green Flare
// "ShotSmokeX"; // M18 Smoke
// "ShotCM" // Plane flares
// "ShotSubmunition" // Hind minigun, cluster artillery
_ammoSimType = getText(configFile >> "CfgAmmo" >> _ammo >> "simulation");

// Save marker data to projectile namespace for EH later
_projectile setVariable [QGVAR(firer), _firer];
_projectile setVariable [QGVAR(firerId), _firerId];

// BULLET PROJECTILES

if (_ammoSimType isEqualTo "shotBullet") exitWith {};

// ALL OTHER PROJECTILES

// get data for marker
([_weapon, _muzzle, _ammo, _magazine, _projectile, _vehicle, _ammoSimType] call FUNC(getAmmoMarkerData)) params ["_markTextLocal", "_markName", "_markColor", "_markerType"];
private _magIcon = getText(configFile >> "CfgMagazines" >> _magazine >> "picture");
_projectile setVariable [QGVAR(markName), _markName];

// MAKE MARKER for PLAYBACK
_firerPos = getPosASL _firer;
[QGVARMAIN(handleMarker), ["CREATED", _markName, _firer, _firerPos, _markerType, "ICON", [1, 1], getDirVisual _firer, "Solid", _markColor, 1, _markTextLocal, true]] call CBA_fnc_localEvent;

// move marker, then delete marker, when projectile is deleted or explodes
_projectile addEventHandler ["Deleted", {
	params ["_projectile"];
	_markName = _projectile getVariable QGVAR(markName);
	_firer = _projectile getVariable QGVAR(firer);
	[QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, getPosASL _projectile, "", "", "", getDir _projectile, "", "", 1]] call CBA_fnc_localEvent;
	[{
		[QGVARMAIN(handleMarker), ["DELETED", _this]] call CBA_fnc_localEvent;
	}, _markName, GVAR(frameCaptureDelay) * 3] call CBA_fnc_waitAndExecute;
}];

_projectile addEventHandler ["Explode", {
	params ["_projectile", "_pos", "_velocity"];
	_markName = _projectile getVariable QGVAR(markName);
	_firer = _projectile getVariable QGVAR(firer);
	[QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, _pos, "", "", "", getDir _projectile, "", "", 1]] call CBA_fnc_localEvent;
	[{
		[QGVARMAIN(handleMarker), ["DELETED", _this]] call CBA_fnc_localEvent;
	}, _markName, GVAR(frameCaptureDelay) * 3] call CBA_fnc_waitAndExecute;
}];

// Add to debug
if (GVARMAIN(isDebug)) then {
	// add to map draw array
	private _debugArr = [_projectile, _magIcon, format["%1 %2 - %3", str side group _firer, name _firer, _markTextLocal], [side group _firer] call BIS_fnc_sideColor];
	[QGVAR(addDebugMagIcon), _debugArr] call CBA_fnc_globalEvent;
};

switch (true) do {
	case (_ammoSimType in ["shotGrenade", "shotIlluminating", "shotMine", "shotSmokeX", "shotCM"]): {
		GVAR(liveGrenades) pushBack [_projectile, _wepString, _firer, getPosASL _projectile, _markName, _markTextLocal, _ammoSimType];
	};

	default {
		// case (_ammoSimType in ["shotMissile", "shotRocket", "shotShell", "shotSubmunitions"]):
		GVAR(liveMissiles) pushBack [_projectile, _wepString, _firer, getPosASL _projectile, _markName, _markTextLocal];

		if (_ammoSimType isEqualTo "shotSubmunitions") then {
			_projectile setVariable [QGVAR(markerData), ([_weapon, _muzzle, _ammo, _magazine, _projectile, _vehicle, _ammoSimType] call FUNC(getAmmoMarkerData))];
			_projectile setVariable [QGVAR(EHData), [_this, _subTypes, _magazine, _wepString, _firer, _firerId, _firerPos, _frame, _ammoSimType, _subTypesAmmoSimType]];

			            // for every submunition split process here
			_projectile addEventHandler ["SubmunitionCreated", {
				params ["_projectile", "_submunitionProjectile", "_pos", "_velocity"];
				(_projectile getVariable [QGVAR(markerData), []]) params ["_markTextLocal", "_markName", "_markColor", "_markerType"];
				(_projectile getVariable [QGVAR(EHData), []]) params ["_EHData", "_subTypes", "_magazine", "_wepString", "_firer", "_firerId", "_firerPos", "_frame", "_ammoSimType", "_subTypesAmmoSimType"];

				                // Save marker data to projectile namespace for EH later
				_submunitionProjectile setVariable [QGVAR(firer), _firer];
				_submunitionProjectile setVariable [QGVAR(firerId), _firerId];
				_submunitionProjectile setVariable [QGVAR(markName), _markName];

				private _magIcon = getText(configFile >> "CfgMagazines" >> _magazine >> "picture");

				                // then get data of submunition to determine how to track it
				private _ammoSimType = getText(configOf _submunitionProjectile >> "simulation");

				if (_ammoSimType isEqualTo "shotBullet") exitWith {};

				_submunitionProjectile addEventHandler ["Deleted", {
					// move marker, then delete marker, when projectile is deleted or explodes
					params ["_projectile"];
					_markName = _projectile getVariable QGVAR(markName);
					_firer = _projectile getVariable QGVAR(firer);
					[QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, getPosASL _projectile, "", "", "", getDir _projectile, "", "", 1]] call CBA_fnc_localEvent;
					[{
						[QGVARMAIN(handleMarker), ["DELETED", _this]] call CBA_fnc_localEvent;
					}, _markName, GVAR(frameCaptureDelay) * 3] call CBA_fnc_waitAndExecute;
				}];

				_projectile addEventHandler ["Explode", {
					params ["_projectile", "_pos", "_velocity"];
					_markName = _projectile getVariable QGVAR(markName);
					_firer = _projectile getVariable QGVAR(firer);
					[QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, _pos, "", "", "", getDir _projectile, "", "", 1]] call CBA_fnc_localEvent;
					[{
						[QGVARMAIN(handleMarker), ["DELETED", _this]] call CBA_fnc_localEvent;
					}, _markName, GVAR(frameCaptureDelay) * 3] call CBA_fnc_waitAndExecute;
				}];

				if (GVARMAIN(isDebug)) then {
					// Add to debug
					// add to map draw array
					private _debugArr = [_projectile, _magIcon, format["%1 %2 - %3", str side group _firer, name _firer, _markTextLocal], [side group _firer] call BIS_fnc_sideColor];
					[QGVAR(addDebugMagIcon), _debugArr] call CBA_fnc_globalEvent;
				};

				switch (true) do {
					case (_ammoSimType in ["shotGrenade", "shotIlluminating", "shotMine", "shotSmokeX", "shotCM"]): {
						GVAR(liveGrenades) pushBack [_submunitionProjectile, _wepString, _firer, getPosASL _submunitionProjectile, _markName, _markTextLocal, _ammoSimType];
					};

					default {
						// case (_ammoSimType in ["shotMissile", "shotRocket", "shotShell", "shotSubmunitions"]):
						GVAR(liveMissiles) pushBack [_submunitionProjectile, _wepString, _firer, getPosASL _submunitionProjectile, _markName, _markTextLocal];
					};
				};
			}];
		};
	};
};
