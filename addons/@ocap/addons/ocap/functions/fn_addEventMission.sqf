/* ----------------------------------------------------------------------------
Script: ocap_fnc_addEventMission

Description:
	Used for applying mission event handlers.

	* Applied during initialization of OCAP2 in <ocap_fnc_init>.

Parameters:
	None

Returns:
	Nothing

Examples:
	--- Code
	call ocap_fnc_addEventMission;
	---

Public:
	No

Author:
	IndigoFox, Dell
---------------------------------------------------------------------------- */

addMissionEventHandler["HandleDisconnect", {
	_this call ocap_fnc_eh_disconnected;
}];

addMissionEventHandler["PlayerConnected", {
	_this call ocap_fnc_eh_connected;
}];

addMissionEventHandler ["EntityKilled", {
	_this call ocap_fnc_eh_killed;
}];

addMissionEventHandler ["EntityRespawned", {
	params ["_entity", "_corpse"];

	// Reset unit back to normal
	_entity setvariable ["ocapIsKilled", false];

	// Stop tracking old unit
	if (_corpse getVariable ["ocap_isInitialised", false]) then {
		_corpse setVariable ["ocap_exclude", true];

		[_entity, true] spawn ocap_fnc_addEventHandlers;
	};
}];

if (isClass (configFile >> "CfgPatches" >> "ace_explosives")) then {
	call ocap_fnc_trackAceExplPlace;
};

if (ocap_saveMissionEnded) then {
	addMissionEventHandler ["MPEnded", {
		["Mission ended automatically"] call ocap_fnc_exportData;
	}];
};

// Custom event handler
ocap_customEvent_handle = ["ocap_handleCustomEvent", {
	_this call ocap_fnc_handleCustomEvent;
}] call CBA_fnc_addEventHandler;

// Add event saving markers
call ocap_fnc_handleMarkers;

["WMT_fnc_EndMission", {
	_this call ocap_fnc_exportData;
}] call CBA_fnc_addEventHandler;
