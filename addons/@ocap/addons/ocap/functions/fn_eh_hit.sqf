params ["_unit", "_causedBy", "_damage", "_instigator"];
_unitID = _unit getVariable "ocap_id";

private _eventData = [ocap_captureFrameNo, "hit", _unitID, ["null"], -1];
if (!isNull _causedBy) then {
	_causedByInfo = [];
	if (_causedBy isKindOf "CAManBase") then {
		_causedByInfo = [
			_causedBy getVariable "ocap_id",
			getText (configFile >> "CfgWeapons" >> currentWeapon _causedBy >> "displayName")
		];
	} else {
		_causedByInfo = [_causedBy getVariable "ocap_id"];
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
