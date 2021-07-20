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
		private _eventData = [];
		// [ocap_captureFrameNo, "killed", _victimId, ["null"], -1];

		if (!isNull _instigator) then {
			_killerId = _instigator getVariable ["ocap_id", -1];
			if (_killerId == -1) exitWith {};

			private _killerInfo = [];
			if (_instigator isKindOf "CAManBase") then {
				_causedByInfo = [
					_instigatorId,
					([_instigator] call ocap_fnc_getEventWeaponText)
				];
			} else {
				_causedByInfo = [_killerId];
			};

			_eventData = [
				ocap_captureFrameNo,
				"killed",
				_victimId,
				_causedByInfo,
				round(_instigator distance _victim)
			];
		};

		[":EVENT:", _eventData] call ocap_fnc_extension;
	};
};
