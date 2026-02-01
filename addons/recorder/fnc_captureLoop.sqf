/* ----------------------------------------------------------------------------
FILE: fnc_captureLoop.sqf

FUNCTION: OCAP_recorder_fnc_captureLoop

Description:

  This function is run unscheduled and creates a CBA PerFrameHandler object, a logic object which executes code every specified interval (<OCAP_settings_frameCaptureDelay>) while a condition (<SHOULDSAVEEVENTS>) is true.

  Iterates through units and vehicles, declares they exist, and conditionally sends their information to the extension to populate recording data.

  This is the core processing loop that determines when new units enter the world, all the details about them, classifies which to exclude, and determines their health/life status. It has both unit and vehicle tracking.

Parameters:
  None

Returns:
  Nothing

Examples:
  >  call FUNC(captureLoop);

Public:
  No

Author:
  Dell, Zealot, IndigoFox, Fank
---------------------------------------------------------------------------- */

#include "script_component.hpp"

if (!isNil QGVAR(PFHObject)) then {
  [GVAR(PFHObject)] call CBA_fnc_deletePerFrameHandlerObject;
  GVAR(PFHObject) = nil;
};
if (isNil QGVAR(startTime)) then {
  GVAR(startTime) = time;
  publicVariable QGVAR(startTime);
  OCAPEXTLOG(ARR3(__FILE__, QGVAR(recording) + " started, time:", GVAR(startTime)));
  LOG(ARR3(__FILE__, QGVAR(recording) + " started, time:", GVAR(startTime)));
};

// Variable: OCAP_PFHObject
// The CBA PerFrameHandler object that is created and used to run the capture loop.
GVAR(PFHObject) = [
  {
    private _loopStart = diag_tickTime;

    if (GVAR(captureFrameNo) == 10 || (GVAR(captureFrameNo) > 10 && EGVAR(settings,trackTimes) && GVAR(captureFrameNo) % EGVAR(settings,trackTimeInterval) == 0)) then {
      [] call FUNC(updateTime);
    };

    // every 15 frames of recording check respawn ticket state of each of three sides
    if (GVAR(captureFrameNo) % (30 / GVAR(frameCaptureDelay)) == 0 && EGVAR(settings,trackTickets)) then {
      private _scores = [];
      {
        _scores pushBack ([_x] call BIS_fnc_respawnTickets);
      } forEach [missionNamespace, east, west, independent];
      [QGVARMAIN(customEvent), ["respawnTickets", _scores]] call CBA_fnc_localEvent;
    };

    // update diary record every 320 frames
    if (GVAR(captureFrameNo) % (320 / GVAR(frameCaptureDelay)) == 0) then {
      publicVariable QGVAR(captureFrameNo);
      {
        player createDiaryRecord [
          "OCAPInfo",
          [
            "Status",
            ("<font color='#CCCCCC'>Capture frame: " + str (missionNamespace getVariable [QGVAR(captureFrameNo), "[not yet received]"]) + "</font>")
          ]
        ];
      } remoteExec ["call", 0, false];
    };

    {
      if !(_x getVariable [QGVARMAIN(isInitialized), false]) then {
        if (
          _x isKindOf "Logic"
        ) exitWith {
          _x setVariable [QGVARMAIN(exclude), true, true];
          _x setVariable [QGVARMAIN(isInitialized), true, true];
        };
        _x setVariable [QGVARMAIN(id), GVAR(nextId)];
        private _newUnit = [
          GVAR(captureFrameNo), //1
          GVAR(nextId), //2
          name _x, //3
          groupID (group _x), //4
          str side group _x, //5
          BOOL(isPlayer _x), //6
          roleDescription _x // 7
        ];
        [":NEW:UNIT:", _newUnit] call EFUNC(extension,sendData);
        _x setVariable [QGVARMAIN(newUnitData), _newUnit];

        if (
          missionNamespace getVariable [
            QEGVAR(database,enabled), false]
        ) then {
          _newUnit pushBack (typeOf _x); // 8 classname
          _newUnit pushBack ([configOf _x] call BIS_fnc_displayName); // 9 type displayname
          if (isPlayer _x) then { // 10 player uid
            _newUnit pushBack (getPlayerUID _x);
          } else {
            _newUnit pushBack "";
          };
          _newUnit pushBack ([squadParams _x] call CBA_fnc_encodeJSON); // 11 squad params

          [
            {missionNamespace getVariable [QEGVAR(database,dbValid), false]},
            {[":NEW:SOLDIER:", _this] call EFUNC(database,sendData);},
            _newUnit,
            30
          ] call CBA_fnc_waitUntilAndExecute;
        };

        [_x] spawn FUNC(addUnitEventHandlers);
        GVAR(nextId) = GVAR(nextId) + 1;
        _x setVariable [QGVARMAIN(isInitialized), true, true];
      };
      if !(_x getVariable [QGVARMAIN(exclude), false]) then {
        private _unitRole = _x getVariable [QGVARMAIN(unitType), ""];
        if (GVAR(captureFrameNo) % 10 == 0 || _unitRole == "") then {
          _unitRole = [_x] call FUNC(getUnitType);
          _x setVariable [QGVARMAIN(unitType), _unitRole];
        };

        private _lifeState = 0;
        if (alive _x) then {
          if (EGVAR(settings,preferACEUnconscious) && !isNil "ace_common_fnc_isAwake") then {
            _lifeState = if ([_x] call ace_common_fnc_isAwake) then {1} else {2};
          } else {
            _lifeState = if (lifeState _x isEqualTo "INCAPACITATED") then {2} else {1};
          };
        };

        _pos = getPosASL _x;

        private _unitData = [
          (_x getVariable QGVARMAIN(id)), //1
          _pos, //2
          round getDir _x, //3
          _lifeState, //4
          BOOL(!((vehicle _x) isEqualTo _x)),  //5
          if (alive _x) then {name _x} else {""}, //6
          BOOL(isPlayer _x), //7
          _unitRole //8
        ];

        if (_x getVariable ["unitData", []] isNotEqualTo _unitData) then {
          [":UPDATE:UNIT:", _unitData] call EFUNC(extension,sendData);
          _x setVariable [QGVARMAIN(unitData), _unitData];
        };

        if (
          missionNamespace getVariable [QEGVAR(database,dbValid), false] &&
          missionNamespace getVariable [QEGVAR(database,enabled), false]
        ) then {
          _unitData pushBack GVAR(captureFrameNo); // frame 9
          if (!isNil "ace_medical_status_fnc_hasStableVitals") then {
            // ACE3 medical
            // has stable vitals 10
            // is being dragged or carried 11
            _unitData pushBack BOOL([_x] call ace_medical_status_fnc_hasStableVitals);
            _unitData pushBack BOOL([_x] call ace_medical_status_fnc_isBeingDragged);
          } else {
            // vanilla medical
            // default true, false
            _unitData pushBack true;
            _unitData pushBack false;
          };

          _unitData pushBack (
            (getPlayerScores _x) joinString ","
          ); // scores 12
          _unitData pushBack (
            _x call CBA_fnc_vehicleRole
          ); // vehicle role ("driver", "cargo", "gunner", "crew", "turret") 13
          if (!isNull objectParent _x) then {
            _unitData pushBack ((objectParent _x) getVariable [QGVARMAIN(id), -1]); // 14
          } else {
            _unitData pushBack -1;
          };
          _unitData pushBack (stance _x); // 15


          [":NEW:SOLDIER:STATE:", _unitData] call EFUNC(database,sendData);
        };
      };
      false
    } count (allUnits + allDeadMen);


    {
      if !(_x getVariable [QGVARMAIN(isInitialized), false]) then {
        _vehType = typeOf _x;
        _class = _vehType call FUNC(getClass);
        private _toExcludeKind = false;
        if (count (parseSimpleArray EGVAR(settings,excludeKindFromRecord)) > 0) then {
          private _vic = _x;
          {
            if (_vic isKindOf _x) exitWith {
              _toExcludeKind = true;
            };
          } forEach (parseSimpleArray EGVAR(settings,excludeKindFromRecord));
        };
        private _toExcludeClass = false;
        if (count (parseSimpleArray EGVAR(settings,excludeClassFromRecord)) > 0) then {
          {
            if (typeOf _vic == _x) exitWith {
              _toExcludeClass = true;
            };
          } forEach (parseSimpleArray EGVAR(settings,excludeClassFromRecord));
        };
        if ((_class isEqualTo "unknown") || _toExcludeKind || _toExcludeClass) exitWith {
          LOG(ARR2("WARNING: vehicle is defined as 'unknown' or exclude:", _vehType));
          _x setVariable [QGVARMAIN(isInitialized), true, true];
          _x setVariable [QGVARMAIN(exclude), true, true];
        };

        _x setVariable [QGVARMAIN(id), GVAR(nextId)];

        private _newVehicleData = [
          GVAR(captureFrameNo), //1
          GVAR(nextId), //2
          _class, //3
          getText (configFile >> "CfgVehicles" >> _vehType >> "displayName") //4
        ];

        [":NEW:VEH:", _newVehicleData] call EFUNC(extension,sendData);
        _x setVariable [QGVARMAIN(newVehicleData), _newVehicleData];

        if (
          missionNamespace getVariable [
            QEGVAR(database,enabled), false]
        ) then {
          _newVehicleData pushBack (typeOf _x);
          _newVehicleData pushBack format ["%1", [_x] call BIS_fnc_getVehicleCustomization];
          [
            {missionNamespace getVariable [QEGVAR(database,dbValid), false]},
            {[":NEW:VEHICLE:", _this] call EFUNC(database,sendData);},
            _newVehicleData,
            30
          ] call CBA_fnc_waitUntilAndExecute;
        };
        [_x] spawn FUNC(addUnitEventHandlers);
        GVAR(nextId) = GVAR(nextId) + 1;
        _x setVariable [QGVARMAIN(vehicleClass), _class];
        _x setVariable [QGVARMAIN(isInitialized), true, true];
      };
      if !(_x getVariable [QGVARMAIN(exclude), false]) then {
        private _crew = [];
        {
          if (_x getVariable [QGVARMAIN(isInitialized), false]) then {
            _crew pushBack (_x getVariable QGVARMAIN(id));
          }; false
        } count (crew _x);
        _pos = getPosASL _x;

        private _vehicleData = [
          (_x getVariable QGVARMAIN(id)), //1
          _pos, //2
          round getDir _x, //3
          BOOL(alive _x), //4
          _crew, //5
          GVAR(captureFrameNo) // 6
        ];
        [":UPDATE:VEH:", _vehicleData] call EFUNC(extension,sendData);

        if (
          missionNamespace getVariable [QEGVAR(database,dbValid), false] &&
          missionNamespace getVariable [QEGVAR(database,enabled), false]
        ) then {
          _vehicleData pushBack (fuel _x); // 7
          _vehicleData pushBack (damage _x); // 8
          _vehicleData pushBack (isEngineOn _x); // 9
          _vehicleData pushBack ((locked _x) >= 2); // 10
          _vehicleData pushBack (side _x); // 11
          toFixed 2;
          _vehicleData pushBack (vectorDir _x); // 12
          _vehicleData pushBack (vectorUp _x); // 13

          ([_x, [0], true] call CBA_fnc_turretDir) params
            ["_turretAz", "_turretEl"];
          _vehicleData pushBack _turretAz; // 14
          _vehicleData pushBack _turretEl; // 15
          toFixed -1;

          [":NEW:VEHICLE:STATE:", _vehicleData] call EFUNC(database,sendData);
        };
      };
      false
    } count vehicles;

    if (GVARMAIN(isDebug)) then {
      private _logStr = format["Frame %1 processed in %2ms", GVAR(captureFrameNo), diag_tickTime - _loopStart];
      OCAPEXTLOG([_logStr]);
      _logStr SYSCHAT;
    };

    GVAR(captureFrameNo) = GVAR(captureFrameNo) + 1;
    publicVariable QGVAR(captureFrameNo);
  },
  GVAR(frameCaptureDelay), // delay
  [], // args
  {}, // code, executed when added
  {}, // code, executed when removed
  {SHOULDSAVEEVENTS}, // if true, execute PFH cycle
  {false} // if true, delete object
] call CBA_fnc_createPerFrameHandlerObject;
