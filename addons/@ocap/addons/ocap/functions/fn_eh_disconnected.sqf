params ["_unit", "_id", "_uid", "_name"];

[":EVENT:",
	[ocap_captureFrameNo, "disconnected", _name]
] call ocap_fnc_extension;

if (_unit getVariable ["ocap_isInitialised", false]) then {
	_unit setVariable ["ocap_exclude", true];
};
