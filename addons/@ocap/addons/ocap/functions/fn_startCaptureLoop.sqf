/* ----------------------------------------------------------------------------
Script: ocap_fnc_startCaptureLoop

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
	0 spawn ocap_fnc_startCaptureLoop;
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

// bool: ocap_capture
ocap_capture = true;
ocap_startTime = time;
LOG(ARR3(__FILE__, "ocap_capture start, time:", ocap_startTime));

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


[] call ocap_fnc_updateTime;

private _id = 0;
while {ocap_capture} do {
	isNil {
		if (ocap_captureFrameNo == 10 || (ocap_captureFrameNo > 10 && ocap_trackTimes && ocap_captureFrameNo % ocap_trackTimeInterval == 0)) then {
			[] call ocap_fnc_updateTime;
		};

		if (ocap_captureFrameNo % (60 / ocap_frameCaptureDelay) == 0) then {
			publicVariable "ocap_captureFrameNo";
			{
				player createDiaryRecord [
					"OCAP2Info",
					[
						"Status",
						("<font color='#CCCCCC'>Capture frame: " + str(ocap_captureFrameNo) + "</font>")
					]
				];
			} remoteExecCall ["call", 0, false];
		};

		{
			if !(_x getVariable ["ocap_isInitialised", false]) then {
				if (_x isKindOf "Logic") exitWith {
					_x setVariable ["ocap_exclude", true];
					_x setVariable ["ocap_isInitialised", true];
				};
				_x setVariable ["ocap_id", _id];
				[":NEW:UNIT:", [
					ocap_captureFrameNo, //1
					_id, //2
					name _x, //3
					groupID (group _x), //4
					str side group _x, //5
					BOOL(isPlayer _x), //6
					roleDescription _x // 7
				]] call ocap_fnc_extension;
				[_x] spawn ocap_fnc_addEventHandlers;
				_id = _id + 1;
				_x setVariable ["ocap_isInitialised", true];
			};
			if !(_x getVariable ["ocap_exclude", false]) then {
				private _unitRole = _x getVariable ["ocap_unitType", ""];
				if (ocap_captureFrameNo % 10 == 0 || _unitRole == "") then {
					_unitRole = [_x] call ocap_fnc_getUnitType;
					_x setVariable ["ocap_unitType", _unitRole];
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
					(_x getVariable "ocap_id"), //1
					_pos, //2
					round getDir _x, //3
					_lifeState, //4
					BOOL(!((vehicle _x) isEqualTo _x)),  //5
					if (alive _x) then {name _x} else {""}, //6
					BOOL(isPlayer _x), //7
					_unitRole //8
				]] call ocap_fnc_extension;
			};
			false
		} count (allUnits + allDeadMen);

		{
			if !(_x getVariable ["ocap_isInitialised", false]) then {
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
					_x setVariable ["ocap_isInitialised", true];
					_x setVariable ["ocap_exclude", true];
				};

				_x setVariable ["ocap_id", _id];
				[":NEW:VEH:", [
					ocap_captureFrameNo, //1
					_id, //2
					_class, //3
					getText (configFile >> "CfgVehicles" >> _vehType >> "displayName") //4
				]] call ocap_fnc_extension;
				[_x] spawn ocap_fnc_addEventHandlers;
				_id = _id + 1;
				_x setVariable ["ocap_isInitialised", true];
			};
			if !(_x getVariable ["ocap_exclude", false]) then {
				private _crew = [];
				{
					if (_x getVariable ["ocap_isInitialised", false]) then {
						_crew pushBack (_x getVariable "ocap_id");
					}; false
				} count (crew _x);
				_pos = getPosASL _x;
				// _pos set [2, round(_pos select 2)];
				[":UPDATE:VEH:", [
					(_x getVariable "ocap_id"), //1
					_pos, //2
					round getDir _x, //3
					BOOL(alive _x), //4
					_crew, //5
					ocap_captureFrameNo // 6
				]] call ocap_fnc_extension;
			};
			false
		} count vehicles;
	};
	sleep (call ocap_fnc_getDelay);
	ocap_captureFrameNo = ocap_captureFrameNo + 1;
};
