#include "script_macros.hpp"

params ["_action", "_sides", "_number"];

if (isNil "_action") exitWith {
	LOG(["fn_counterEvent: no action specified"]);
	"fn_counterEvent: no action specified";
};
if (isNil "_sides") exitWith {
	LOG(["fn_counterEvent: no side(s) specified"]);
	"fn_counterEvent: no side(s) specified";
};
if (isNil "_number") exitWith {
	LOG(["fn_counterEvent: no number specified"]);
	"fn_counterEvent: no number specified";
};

if (_number isEqualType "") then {
	_number = parseNumber _number;
};
if (!(_number isEqualType 2)) exitWith {
	LOG(["fn_counterEvent: provided number format is invalid"]);
	"fn_counterEvent: provided number format is invalid";
};

switch (_action) do {
	case "Init": {
		if (count _sides == 0) exitWith {
			LOG(["fn_counterEvent INIT: No sides specified, failed to init counter"]);
			"fn_counterEvent: provided number format is invalid";
		};

		if (!(count (_sides select {_x isEqualType east}) > 0)) exitWith {
			LOG(["fn_counterEvent INIT: Invalid side type specified, should be east, west, independent, etc"]);
			"fn_counterEvent INIT: Invalid side type specified, should be east, west, independent, etc";
		};

		["CounterStart", (_sides apply {str _x}), _number] call ocap_fnc_extension;
		LOG([("fn_counterEvent INIT: score counter initialized with sides " + (_sides apply {str _x}))]);
		"fn_counterEvent INIT: score counter initialized";
	};
	case "Set": {
		if (!(_sides isEqualType east)) exitWith {
			LOG(["fn_counterEvent SET: invalid side type provided"]);
			"fn_counterEvent SET: invalid side type provided";
		};
		["CounterSet", _sides, _number] call ocap_fnc_extension;
		format["fn_counterEvent SET: set %1 to %2 tickets", _sides, _number];
	};
	default {
		LOG(["fn_counterEvent: invalid action parameter"]);
		"fn_counterEvent: invalid action parameter";
	};
};
