/* ----------------------------------------------------------------------------
Script: ocap_fnc_addEventHandlers

Description:
	Used for applying unit-specific event handlers to units during initialization. These event handlers will trigger on the server.

	Applied during initialization of a unit in <FUNC(captureLoop)>.

Parameters:
	_entity - Object to apply event handlers to. [Object]
	_respawn - Determines if unit is initialized for the first time, or has respawned and does not need certain handlers reapplied. [Boolean, defaults to false]

Returns:
	Nothing

Examples:
	--- Code
	[_unit] spawn ocap_fnc_addEventHandlers;
	---

Public:
	No

Author:
	IndigoFox, Fank
---------------------------------------------------------------------------- */

params ["_entity", ["_respawn", false]];

if ((_entity call BIS_fnc_objectType) # 0 == "Soldier") then {
	_entity addEventHandler ["FiredMan", { _this spawn ocap_fnc_eh_fired; }];
};
_entity addMPEventHandler ["MPHit", { _this spawn ocap_fnc_eh_hit; }];

if (
	!_respawn &&
	(_entity call BIS_fnc_objectType) # 0 == "Soldier" &&
	isClass (configFile >> "CfgPatches" >> "ace_advanced_throwing")
) then {
	ocap_fnc_trackAceThrowing remoteExec ["call", _entity];
};
