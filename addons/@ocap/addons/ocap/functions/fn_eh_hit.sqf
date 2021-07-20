params ["_unit", "_causedBy", "_damage", "_instigator"];

[_unit, _causedBy, _instigator] spawn {
	params ["_unit", "_causedBy", "_instigator"];

	if (isNull _instigator) then {
		_instigator = [_unit, _causedBy] call ocap_fnc_getInstigator;
	};

	_unitID = _unit getVariable ["ocap_id", -1];
	if (_unitID == -1) exitWith {};
	private _eventData = [];
	// [ocap_captureFrameNo, "hit", _unitID, ["null"], -1];

	if (!isNull _instigator) then {
		_causedById = _causedBy getVariable ["ocap_id", -1];

		private _causedByInfo = [];
		if (_causedBy isKindOf "CAManBase" && !(_causedById == -1)) then {
			_causedByInfo = [
				_causedById,
				getText (configFile >> "CfgWeapons" >> currentWeapon _causedBy >> "displayName")
			];
		} else {
			if (!isNull _instigator && _causedBy != _instigator && _instigator isKindOf "CAManBase") then {
				_text = [_instigator] call ocap_fnc_getVicWeaponText;
				_causedByInfo = [
					_killerId,
					_text
				];
			} else {
				_causedByInfo = [_causedBy getVariable "ocap_id"];
			};
		};
		_eventData = [
			ocap_captureFrameNo,
			"hit",
			_unitID,
			_causedByInfo,
			round (_unit distance _causedBy)
		];
	};

	[":EVENT:", _eventData] call ocap_fnc_extension;
};
