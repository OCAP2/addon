/* ----------------------------------------------------------------------------
	FILE: fnc_eh_onUserSelectedPlayer.sqf

	FUNCTION: OCAP_recorder_fnc_eh_onUserSelectedPlayer

	Description:
	  Uses <OCAP_EH_OnUserSelectedPlayer> to detect when someone joins the server.

	  Calls <OCAP_recorder_fnc_adminUIControl> to apply the admin UI if the player is in <OCAP_administratorList>.

	Parameters:
	  _networkId - The network ID of the player who has logged in or out of the server [String]
	  _playerObject - player object to be controlled by the user [Object]

	Returns:
	  Nothing

	Examples:
	  > call FUNC(eh_onUserSelectedPlayer);

	Public:
	  No

	Author:
	  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_networkId", "_playerObject"];

// For non-JIP players, OnUserSelectedPlayer fires between preInit and postInit. Since we're initializing in postInit, this function will be too late to handle non-JIP players. Admins in this case are handled by <OCAP_recorder_fnc_init>.
if (!isNull _playerObject) exitWith {
	_playerObject addEventHandler ["Local", {
		params ["_playerObject"];
		_playerObject removeEventHandler [_thisEvent, _thisEventHandler];

		private _networkId = getPlayerID _playerObject;
		[_networkId, "connect"] call FUNC(adminUIcontrol);
	}];
};

// In rare cases, _playerObject may be objNull despite Arma 3 v2.18 allowing the event to be postponed.
// Make a last ditch attempt to wait for the player object to be set (similar to <OCAP_recorder_fnc_init>).
[{
	!isNull (getUserInfo _this param [10, objNull, [objNull]])
}, {
	[_this, "connect"] call FUNC(adminUIcontrol);
}, _networkId, 30, {
	diag_log text format ["[OCAP] (recorder) WARNING: connecting player object is null for PID: %1", _networkId];
}] call CBA_fnc_waitUntilAndExecute;
