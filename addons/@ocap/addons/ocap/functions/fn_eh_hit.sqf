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
		_instigatorId = _instigator getVariable ["ocap_id", -1];

		private _causedByInfo = [];
		private _distanceInfo = 0;
		if (_causedBy isKindOf "CAManBase" && _causedById > -1) then {
			_causedByInfo = [
				_causedById,
				([_causedBy] call ocap_fnc_getEventWeaponText)
			];
			_distanceInfo = round (_unit distance _causedBy);
		} else {
			if (!isNull _instigator && _causedBy != _instigator && _instigator isKindOf "CAManBase" && _instigatorId > -1) then {
				_causedByInfo = [
					_instigatorId,
					([_instigator] call ocap_fnc_getEventWeaponText)
				];
				_distanceInfo = round (_unit distance _instigator);
			} else {
				_causedByInfo = [_causedById];
				_distanceInfo = round (_unit distance _causedBy);
			};
		};
		_eventData = [
			ocap_captureFrameNo,
			"hit",
			_unitID,
			_causedByInfo,
			_distanceInfo
		];
	};

	[":EVENT:", _eventData] call ocap_fnc_extension;
};
