params ["_unit", "_causedBy", "_damage", "_instigator"];

[_unit, _causedBy, _instigator] spawn {
	params ["_unit", "_causedBy", "_instigator"];
	_unitID = _unit getVariable "ocap_id";

	if (isNull _instigator) then {
		_instigator = [_unit, _causedBy] call ocap_fnc_getInstigator;
	};

	private _eventData = [ocap_captureFrameNo, "hit", _unitID, ["null"], -1];
	if (!isNull _causedBy) then {
		_causedByInfo = [];
		if (_causedBy isKindOf "CAManBase") then {
			_causedByInfo = [
				_causedBy getVariable "ocap_id",
				getText (configFile >> "CfgWeapons" >> currentWeapon _causedBy >> "displayName")
			];
		} else {
			if (!isNull _instigator && _causedBy != _instigator && _instigator isKindOf "CAManBase") then {
				// pilot/driver doesn't return a value, so check for this
				private _turPath = [];
				if (count (assignedVehicleRole _instigator) > 1) then {
					_turPath = assignedVehicleRole _instigator select 1;
				} else {
					_turPath = [-1];
				};

				private _curVic = getText(configFile >> "CfgVehicles" >> (typeOf vehicle _instigator) >> "displayName");
				(weaponstate [vehicle _causedBy, _turPath]) params ["_curWep", "_curMuzzle", "_curFiremode", "_curMag"];
				private _curWepDisplayName = getText(configFile >> "CfgWeapons" >> _curWep >> "displayName");
				private _curMagDisplayName = getText(configFile >> "CfgMagazines" >> _curMag >> "displayName");
				private _text = "";
				if (count _curMagDisplayName < 22) then {
					_text = _curVic + " [" + _curWepDisplayName + " / " + _curMagDisplayName + "]";
				} else {
					if (_curWep != _curMuzzle) then {
						_text = _curVic + " [" + _curWepDisplayName + " / " + _curMuzzle + "]";
					} else {
						_text = _curVic + " [" + _curWepDisplayName + "]";
					};
				};

				_causedByInfo = [
					_instigator getVariable "ocap_id",
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
