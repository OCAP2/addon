/* ----------------------------------------------------------------------------
Script: ocap_fnc_trackAceExplPlace

Description:
	Adds Init code for any ACE_Explosives_Place object that is created, i.e. when a unit uses ACE self-interaction to place down an explosive.

	The Init code will spawn an instance of <ocap_fnc_trackAceExplLife>.

Parameters:
	None

Returns:
	Nothing

Examples:
	--- Code
	call ocap_fnc_trackAceExplPlace;
	---

Public:
	No

Author:
	IndigoFox
---------------------------------------------------------------------------- */

// on any ACE explosive or mine *placement* via interaction menu, will execute the code here
["ACE_Explosives_Place", "init", {

	if (!isServer) exitWith {};
	_placedPos = getPosASL (_this # 0);
	[(_this # 0), _placedPos] spawn ocap_fnc_trackAceExplLife;

}] call CBA_fnc_addClassEventHandler;
