#include "script_macros.hpp"

params ["_toMonitor"];


if (isNil "_toMonitor") exitWith {
	LOG(["fn_respawnTickets: No target specified, failed to init ticket monitor"]);
	"fn_respawnTickets: No target specified, failed to init ticket monitor";
};

if !(_toMonitor isEqualType []) exitWith {
	LOG(["fn_respawnTickets: Invalid parameter (requires array of ""Global"", Side, Group, or Object), failed to init ticket monitor"]);
	"fn_respawnTickets: Invalid parameter (requires array of ""Global"", Side, Group, or Object), failed to init ticket monitor";
};

if (count _toMonitor > 0) then {
	_processedToMonitor = {
		switch (typeName _x) do {
			case "STRING": {
				if (_x != "Global") exitWith {
					LOG(["fn_respawnTickets: Invalid string provided in parameter array. Accepted values: ""Global"""]);
					false
				};
				true
			};
			default {true};
		};
	} count _toMonitor;
	ocap_respawnTickets append _processedToMonitor;
};
