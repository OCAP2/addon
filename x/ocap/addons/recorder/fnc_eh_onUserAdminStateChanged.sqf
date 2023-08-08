/* ----------------------------------------------------------------------------
	FILE: fnc_eh_onUserAdminStateChanged.sqf

	FUNCTION: OCAP_recorder_fnc_eh_onUserAdminStateChanged

	Description:
	  Uses <OCAP_EH_OnUserAdminStateChanged> to detect when someone is has logged in or out of the server and calls <OCAP_recorder_fnc_adminUIControl> to update the admin UI.

	Parameters:
	  _networkId - The network ID of the player who has logged in or out of the server [String]
	  _loggedIn - Whether the player has logged in or out as admin [Boolean]
	  _votedIn - Whether the player has been voted in or out of admin [Boolean]

	Returns:
	  Nothing

	Examples:
	  > call FUNC(eh_onUserAdminStateChanged);

	Public:
	  No

	Author:
	  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_networkId", "_loggedIn", "_votedIn"];

if (_loggedIn && !_votedIn) exitWith {
	// if user has become admin by logging, not voting, trigger control addition check
	[_networkId, "login"] call FUNC(adminUIcontrol);
};
if (!_loggedIn) then {
	// if user has logged out, trigger admin control removal
	[_networkId, "logout"] call FUNC(adminUIcontrol);
};
