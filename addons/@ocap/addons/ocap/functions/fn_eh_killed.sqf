/* ----------------------------------------------------------------------------
Script: ocap_fnc_eh_killed

Description:
	Tracks when a unit is killed. This is the code triggered by the "MPKilled" Event Handler applied to units during <ocap_fnc_addEventHandlers>.

Parameters:
	_unit - Object the event handler is assigned to. [Object]
	_killer - Object that killed the unit. [Object]
	_instigator - Person who pulled the trigger. [Object]
	_useEffects - same as useEffects in setDamage alt syntax. [Boolean]

Returns:
	Nothing

Examples:
	--- Code
	---

Public:
	No

Author:
	Dell, IndigoFox, Fank
---------------------------------------------------------------------------- */

#include "script_macros.hpp";
params ["_victim", "_killer", "_instigator"];
if !(_victim getvariable ["ocapIsKilled",false]) then {
	_victim setvariable ["ocapIsKilled",true];

	[_victim, _killer, _instigator] spawn {
		params ["_victim", "_killer", "_instigator"];
		if (_killer == _victim) then {
			private _time = diag_tickTime;
			[_victim, {
				_this setVariable ["ace_medical_lastDamageSource", (_this getVariable "ace_medical_lastDamageSource"), 2];
			}] remoteExec ["call", _victim];
			waitUntil {diag_tickTime - _time > 10 || !(isNil {_victim getVariable "ace_medical_lastDamageSource"})};
			_killer = _victim getVariable ["ace_medical_lastDamageSource", _killer];
		} else {
			_killer
		};

		if (isNull _instigator) then {
			_instigator = [_victim, _killer] call ocap_fnc_getInstigator;
		};

		// [ocap_captureFrameNo, "killed", _victimId, ["null"], -1];
		private _victimId = _victim getVariable ["ocap_id", -1];
		if (_victimId == -1) exitWith {};
		private _eventData = [ocap_captureFrameNo, "killed", _victimId, ["null"], -1];

		if (!isNull _instigator) then {
			_killerId = _instigator getVariable ["ocap_id", -1];
			if (_killerId == -1) exitWith {};

			private _killerInfo = [];
			if (_instigator isKindOf "CAManBase") then {
				_killerInfo = [
					_killerId,
					([_instigator] call ocap_fnc_getEventWeaponText)
				];
			} else {
				_killerInfo = [_killerId];
			};

			_eventData = [
				ocap_captureFrameNo,
				"killed",
				_victimId,
				_killerInfo,
				round(_instigator distance _victim)
			];
		};

		DEBUG(_eventData);
		[":EVENT:", _eventData] call ocap_fnc_extension;
	};
};
