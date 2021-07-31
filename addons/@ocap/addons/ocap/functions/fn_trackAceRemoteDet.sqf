// LOG ACE REMOTE DET EVENTS
[{
	params ["_unit", "_range", "_explosive", "_fuzeTime", "_triggerItem"];

	_int = random 2000;

	// expl is ammo, need to find mag, and display name of mag
	_explosiveMag = getText(configFile >> "CfgAmmo" >> (typeOf _explosive) >> "defaultMagazine");
	_explosiveDisp = getText(configFile >> "CfgMagazines" >> _explosiveMag >> "displayName");
	_triggerItemDisp = getText(configFile >> "CfgWeapons" >> _triggerItem >> "displayName");

	_markTextLocal = format["%1", _explosiveDisp];
	_markName = format["Detonation#%1", _int];
	_markColor = "ColorRed";
	_markerType = "waypoint";
	_pos = getPosASL _explosive;

	["ocap_handleMarker", ["CREATED", _markName, _unit, _pos, _markerType, "ICON", [1,1], 0, "Solid", "ColorRed", 1, _markTextLocal, true]] call CBA_fnc_serverEvent;

	[_markName] spawn {
		params ["_markName"];

		sleep 10;
		// [format['["ocap_handleMarker", ["DELETED", %1]] call CBA_fnc_serverEvent;', _markName]] remoteExec ["hint", 0];
		// systemChat format['["ocap_handleMarker", ["DELETED", %1]] call CBA_fnc_serverEvent;', _markName];
		["ocap_handleMarker", ["DELETED", _markName]] call CBA_fnc_serverEvent;
	};
	true;

}] call ace_explosives_fnc_addDetonateHandler;
