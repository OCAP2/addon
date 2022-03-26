/* ----------------------------------------------------------------------------
Script: FUNC(captureLoop)

Description:
	Iterates through units, declares they exist, and conditional records their state at an interval defined in userconfig.hpp.

	This is the core processing loop that determines when new units enter the world, all the details about them, classifies which to exclude, and determines their health/life status. It has both unit and vehicle tracking.

	This is spawned during <ocap_fnc_init>.

Parameters:
	None

Returns:
	Nothing

Examples:
	--- Code
	0 spawn FUNC(captureLoop);
	---

Public:
	No

Author:
	Dell, Zealot, IndigoFox, Fank
---------------------------------------------------------------------------- */

#include "\userconfig\ocap\config.hpp"
#include "script_macros.hpp"

// Function: _isKindOfApc
// Determines whether the vehicle is an APC by checking class inheritance
private _isKindOfApc = {
	_bool = false;
	{
		if (_this isKindOf _x) exitWith {_bool = true;};false
	} count ["Wheeled_APC_F","Tracked_APC","APC_Wheeled_01_base_F","APC_Wheeled_02_base_F",
	"APC_Wheeled_03_base_F","APC_Tracked_01_base_F","APC_Tracked_02_base_F","APC_Tracked_03_base_F"];
	_bool
};

// Function: _getClass
// Gets generalized 'class' of vehicle to determine what icon to assign during playback
private _getClass = {
	if (_this isKindOf "Truck_F") exitWith {"truck"}; // Should be higher than Car
	if (_this call _isKindOfApc) exitWith {"apc"};
	if (_this isKindOf "Car") exitWith {"car"};
	if (_this isKindOf "Tank") exitWith {"tank"};
	if (_this isKindOf "StaticMortar") exitWith {"static-mortar"};
	if (_this isKindOf "StaticWeapon") exitWith {"static-weapon"};
	if (_this isKindOf "ParachuteBase") exitWith {"parachute"};
	if (_this isKindOf "Helicopter") exitWith {"heli"};
	if (_this isKindOf "Plane") exitWith {"plane"};
	if (_this isKindOf "Air") exitWith {"plane"};
	if (_this isKindOf "Ship") exitWith {"sea"};
	"unknown"
};




waitUntil{(count(allPlayers) >= ocap_minPlayerCount)};

// bool: GVAR(capturing)
GVAR(capturing) = true;
GVAR(startTime) = time;
LOG(ARR3(__FILE__, "GVAR(capturing) start, time:", GVAR(startTime)));

{
	[{!isNull player}, {
		player createDiaryRecord [
			"OCAP2Info",
			[
				"Status",
				"<font color='#33FF33'>OCAP2 recording conditions met -- beginning capture.</font>"
			], taskNull, "", false
		];
		player setDiarySubjectPicture [
			"OCAP2Info",
			"\A3\ui_f\data\igui\cfg\simpleTasks\types\use_ca.paa"
		];
	}] call CBA_fnc_waitUntilAndExecute;
} remoteExecCall ["call", 0, true];


[] call FUNC(updateTime);

private _id = 0;
while {GVAR(capturing)} do {
	isNil {
		if (GVAR(captureFrameNo) == 10 || (GVAR(captureFrameNo) > 10 && ocap_trackTimes && GVAR(captureFrameNo) % ocap_trackTimeInterval == 0)) then {
			[] call FUNC(updateTime);
		};

		if (GVAR(captureFrameNo) % (60 / EGVAR(settings,frameCaptureDelay)) == 0) then {
			publicVariable "GVAR(captureFrameNo)";
			{
				player createDiaryRecord [
					"OCAP2Info",
					[
						"Status",
						("<font color='#CCCCCC'>Capture frame: " + str(GVAR(captureFrameNo)) + "</font>")
					]
				];
			} remoteExecCall ["call", 0, false];
		};

		{
			if !(_x getVariable [QGVARMAIN(isInitialized), false]) then {
				if (_x isKindOf "Logic") exitWith {
					_x setVariable [QGVARMAIN(exclude), true];
					_x setVariable [QGVARMAIN(isInitialized), true];
				};
				_x setVariable [QGVARMAIN(id), _id];
				[":NEW:UNIT:", [
					GVAR(captureFrameNo), //1
					_id, //2
					name _x, //3
					groupID (group _x), //4
					str side group _x, //5
					BOOL(isPlayer _x), //6
					roleDescription _x // 7
				]] call EFUNC(extension,sendData);
				[_x] spawn ocap_fnc_addEventHandlers;
				_id = _id + 1;
				_x setVariable [QGVARMAIN(isInitialized), true];
			};
			if !(_x getVariable [QGVARMAIN(exclude), false]) then {
				private _unitRole = _x getVariable [QGVARMAIN(unitType), ""];
				if (GVAR(captureFrameNo) % 10 == 0 || _unitRole == "") then {
					_unitRole = [_x] call ocap_fnc_getUnitType;
					_x setVariable [QGVARMAIN(unitType), _unitRole];
				};

				private _lifeState = 0;
				if (alive _x) then {
					if (ocap_preferACEUnconscious && !isNil "ace_common_fnc_isAwake") then {
						_lifeState = if ([_x] call ace_common_fnc_isAwake) then {1} else {2};
					} else {
						_lifeState = if (lifeState _x isEqualTo "INCAPACITATED") then {2} else {1};
					};
				};

				_pos = getPosASL _x;
				[":UPDATE:UNIT:", [
					(_x getVariable QGVARMAIN(id)), //1
					_pos, //2
					round getDir _x, //3
					_lifeState, //4
					BOOL(!((vehicle _x) isEqualTo _x)),  //5
					if (alive _x) then {name _x} else {""}, //6
					BOOL(isPlayer _x), //7
					_unitRole //8
				]] call EFUNC(extension,sendData);
			};
			false
		} count (allUnits + allDeadMen);

		{
			if !(_x getVariable [QGVARMAIN(isInitialized), false]) then {
				_vehType = typeOf _x;
				_class = _vehType call _getClass;
				_toExcludeKind = false;
				if (count ocap_excludeKindFromRecord > 0) then {
					private _vic = _x;
					{
						if (_vic isKindOf _x) exitWith {
							_toExcludeKind = true;
						};
					} forEach ocap_excludeKindFromRecord;
				};
				if ((_class isEqualTo "unknown") || (_vehType in ocap_excludeClassFromRecord) || _toExcludeKind) exitWith {
					LOG(ARR2("WARNING: vehicle is defined as 'unknown' or exclude:", _vehType));
					_x setVariable [QGVARMAIN(isInitialized), true];
					_x setVariable [QGVARMAIN(exclude), true];
				};

				_x setVariable [QGVARMAIN(id), _id];
				[":NEW:VEH:", [
					GVAR(captureFrameNo), //1
					_id, //2
					_class, //3
					getText (configFile >> "CfgVehicles" >> _vehType >> "displayName") //4
				]] call EFUNC(extension,sendData);
				[_x] spawn ocap_fnc_addEventHandlers;
				_id = _id + 1;
				_x setVariable [QGVARMAIN(isInitialized), true];
			};
			if !(_x getVariable [QGVARMAIN(exclude), false]) then {
				private _crew = [];
				{
					if (_x getVariable [QGVARMAIN(isInitialized), false]) then {
						_crew pushBack (_x getVariable QGVARMAIN(id));
					}; false
				} count (crew _x);
				_pos = getPosASL _x;
				[":UPDATE:VEH:", [
					(_x getVariable QGVARMAIN(id)), //1
					_pos, //2
					round getDir _x, //3
					BOOL(alive _x), //4
					_crew, //5
					GVAR(captureFrameNo) // 6
				]] call EFUNC(extension,sendData);
			};
			false
		} count vehicles;
	};
	sleep (call ocap_fnc_getDelay);
	GVAR(captureFrameNo) = GVAR(captureFrameNo) + 1;
};
