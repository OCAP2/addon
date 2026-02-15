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
