/*
	  FILE: fnc_adminUIControl.sqf

	  FUNCTION: OCAP_recorder_fnc_adminUIControl

	  Description:
	    Runs checks to determine if a player should have the administrative diary entry added or removed upon joining the mission or logging in/out as admin.

	    - <OCAP_recorder_fnc_eh_connected> at mission start to determine if a player is in <OCAP_administratorList>
	    - <OCAP_recorder_fnc_eh_onUserAdminStateChanged> to add/remove when a player logs in or out as admin on the server

	  Parameters:
	    _PID - PlayerID indicating unique network client on the server [String]
	    _event - Event that triggered this call [[String], one of: "connect", "login", "logout"]

	  Returns:
	    Nothing

	  Examples:
	    > ["1234567890", "connect"] call FUNC(adminUIControl);

	  Public:
	    No

	  Author:
	    IndigoFox
*/

#include "script_component.hpp"

params [
	"_PID",
	["_event", "", [""]]
];

if (isNil "_PID") exitWith {
	diag_log text format ["[OCAP] (recorder) WARNING: adminUIcontrol called with nil PID, event: %1", _event];
};

private _userInfo = (getUserInfo _PID);
if (isNil "_userInfo") exitWith {
	diag_log text format ["[OCAP] (recorder) WARNING: getUserInfo returned nil for PID: %1", _PID];
};
if (!(_userInfo isEqualType []) || {count _userInfo < 11}) exitWith {
	diag_log text format ["[OCAP] (recorder) WARNING: getUserInfo returned unexpected data for PID %1: type=%2 count=%3 data=%4", _PID, typeName _userInfo, if (_userInfo isEqualType []) then {count _userInfo} else {-1}, _userInfo];
};
_userInfo params ["_playerID", "_owner", "_playerUID"];
private _unit = _userInfo select 10;
if (isNull _unit) exitWith {
	diag_log text format ["[OCAP] (recorder) WARNING: getUserInfo unit (index 10) is null for PID %1 (UID: %2)", _PID, _playerUID];
};

_fnc_addControls = {
	params ["_owner", "_unit"];
	  // add controls to diary entry
	{
		[{
			getClientStateNumber > 9 && !isNull player
		}, {
			player createDiarySubject [
				QEGVAR(diary,adminControls_subject),
				"OCAP Admin",
				"\A3\ui_f\data\igui\cfg\simpleTasks\types\interact_ca.paa"
			];

			EGVAR(diary,adminControls_record) = player createDiaryRecord [
				QEGVAR(diary,adminControls_subject),
				[
					"Controls",
					format[
						"<br/>These controls can be used to Start Recording, Pause Recording, and Save/Export the Recording. On the backend, these use the corresponding CBA server events that can be found in the documentation. Because of this, they override the default minimum duration required to save, so be aware that clicking ""Stop and Export Recording"" will save and upload your current recording regardless of its duration.<br/><br/><execute expression='[""%1""] call CBA_fnc_serverEvent;
						'>Start/Resume Recording</execute><br/><execute expression='[""%2""] call CBA_fnc_serverEvent;'>Pause Recording</execute><br/><execute expression='[""%3""] call CBA_fnc_serverEvent;'>Stop and Export Recording</execute>",
						QGVARMAIN(record),
						QGVARMAIN(pause),
						QGVARMAIN(exportData)
					]
				]
			];
		}] call CBA_fnc_waitUntilAndExecute;
	} remoteExec ["call", _owner];

	  // set variable on unit
	_unit setVariable [QGVARMAIN(hasAdminControls), true];
};

_fnc_removeControls = {
	params ["_owner", "_unit"];
	{
		player removeDiarySubject QEGVAR(diary,adminControls_subject);
		player setVariable [QGVARMAIN(hasAdminControls), false, 2];
	} remoteExec ["call", _owner];

	  // Variable: OCAP_hasAdminControls
	  // Applied on units processed in <OCAP_recorder_fnc_adminUIControl>. Indicates whether or not they have the administrative diary entry available. Server missionNamespace only.
	_unit setVariable [QGVARMAIN(hasAdminControls), false];
};

// check if admin
private _adminUIDs = missionNamespace getVariable [QGVARMAIN(administratorList), nil];

if (isNil "_adminUIDs") exitWith {
	// At this point, no adminUIDs are defined in missionNamespace or in CBA settings
	WARNING("Failed to parse administrator list setting. Please check its value!");

	switch (_event) do {
		case "connect": {
			// A player just joined the mission and no admin list exists
			// Still check if they are currently a server admin (e.g. mission loaded while already admin)
			if (admin _owner > 0 && {!(_unit getVariable [QGVARMAIN(hasAdminControls), false])}) then {
				[_owner, _unit] call _fnc_addControls;
				if (GVARMAIN(isDebug)) then {
					format["%1 was granted OCAP control by being a server admin", name _unit] SYSCHAT;
				};
			};
		};
		case "login": {
			// A player just logged in so add controls if they don't already have them
			if !(_unit getVariable [QGVARMAIN(hasAdminControls), false]) then {
				[_owner, _unit] call _fnc_addControls;
				if (GVARMAIN(isDebug)) then {
					format["%1 was granted OCAP control by logging in as admin", name _unit] SYSCHAT;
				};
			};
		};
		case "logout": {
			// A player just logged out so remove controls if they have them
			if (_unit getVariable [QGVARMAIN(hasAdminControls), false]) then {
				[_owner, _unit] call _fnc_removeControls;
				if (GVARMAIN(isDebug)) then {
					format["%1 had their admin controls removed due to logging out from admin", name _unit] SYSCHAT;
				};
			};
		};
		default {};
	};
};

// admin list is defined, so we check if the player is listed by playerUID
private _inAdminList = _playerUID in _adminUIDs;

switch (_event) do {
	case "connect": {
		// A player just joined the mission
		// if they are in the admin list OR already a server admin, add the diary entry
		if ((_inAdminList || {admin _owner > 0}) && {!(_unit getVariable [QGVARMAIN(hasAdminControls), false])}) then {
			[_owner, _unit] call _fnc_addControls;
			if (GVARMAIN(isDebug)) then {
				private _reason = if (_inAdminList) then {"being in the administratorList"} else {"being a server admin"};
				format["%1 was granted OCAP control due to %2", name _unit, _reason] SYSCHAT;
			};
		};
	};
	case "login": {
		// A player just logged in so add controls if they don't already have them
		if !(_unit getVariable [QGVARMAIN(hasAdminControls), false]) then {
			[_owner, _unit] call _fnc_addControls;
			if (GVARMAIN(isDebug)) then {
				format["%1 was granted OCAP control by logging in as admin", name _unit] SYSCHAT;
			};
		};
	};
	case "logout": {
		// A player just logged out so remove controls if they have them
		if (_unit getVariable [QGVARMAIN(hasAdminControls), false]) then {
			[_owner, _unit] call _fnc_removeControls;
			if (GVARMAIN(isDebug)) then {
				format["%1 had their admin controls removed due to logging out from admin", name _unit] SYSCHAT;
			};
		};
	};
	default {};
};
