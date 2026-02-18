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
  OCAPEXTLOG(ARR3(__FILE__,QGVAR(recording) + localize LSTRING(RecordingStartedLog),GVAR(startTime)));
  LOG(ARR3(__FILE__,QGVAR(recording) + localize LSTRING(RecordingStartedLog),GVAR(startTime)));
};

GVAR(trackedVehicles) = createHashMap;

// Pre-compute frame intervals that depend on frameCaptureDelay (constant for the mission)
// Must be GVARs, not private — PFH code runs in a different scope.
GVAR(ticketInterval) = round (30 / GVAR(frameCaptureDelay));
GVAR(diaryInterval) = round (320 / GVAR(frameCaptureDelay));

// Variable: OCAP_PFHObject
// The CBA PerFrameHandler object that is created and used to run the capture loop.
GVAR(PFHObject) = [
  {
    private _loopStart = diag_tickTime;

    if (GVAR(captureFrameNo) == 10 || (GVAR(captureFrameNo) > 10 && EGVAR(settings,trackTimes) && GVAR(captureFrameNo) % EGVAR(settings,trackTimeInterval) == 0)) then {
      [] call FUNC(updateTime);
    };

    // every 15 frames of recording check respawn ticket state of each of three sides
    if (GVAR(captureFrameNo) % GVAR(ticketInterval) == 0 && EGVAR(settings,trackTickets)) then {
      private _scores = [];
      {
        _scores pushBack ([_x] call BIS_fnc_respawnTickets);
      } forEach [missionNamespace, east, west, independent];
      [QGVARMAIN(customEvent), ["respawnTickets", _scores]] call CBA_fnc_localEvent;
    };

    // update diary record every ~320 seconds
    if (GVAR(captureFrameNo) % GVAR(diaryInterval) == 0) then {
      publicVariable QGVAR(captureFrameNo);
      [
        [
          localize LSTRING(Status),
          localize LSTRING(CaptureFrame),
          localize LSTRING(NotYetReceived)
        ],
        {
          player createDiaryRecord [
            "OCAPInfo",
            [
              _this select 0,
              format[
                "<font color='#CCCCCC'>%1 %2</font>",
                _this select 1,
                missionNamespace getVariable [QGVAR(captureFrameNo), _this select 2]
              ]
            ]
          ];
        }
      ] remoteExec ["call", 0, false];
    };

    {
      private _justInitialized = false;
      if !(_x getVariable [QGVARMAIN(isInitialized), false]) then {
        if (
          _x isKindOf "Logic"
        ) exitWith {
          _x setVariable [QGVARMAIN(exclude), true, true];
          _x setVariable [QGVARMAIN(isInitialized), true, true];
        };
        _x setVariable [QGVARMAIN(id), GVAR(nextId), true];
        private _newUnit = [
          GVAR(captureFrameNo), //1
          GVAR(nextId), //2
          name _x, //3
          groupID (group _x), //4
          str side group _x, //5
          BOOL(isPlayer _x), //6
          roleDescription _x, // 7
          typeOf _x, // 8 classname
          [configOf _x] call BIS_fnc_displayName, // 9 type displayname
          if (isPlayer _x) then {getPlayerUID _x} else {""}, // 10 player uid
          [squadParams _x] call CBA_fnc_encodeJSON // 11 squad params
        ];
        _x setVariable [QGVARMAIN(newUnitData), _newUnit];

        [
          {missionNamespace getVariable [QEGVAR(database,dbValid), false]},
          {[":NEW:SOLDIER:", _this] call EFUNC(extension,sendData);},
          _newUnit,
          30
        ] call CBA_fnc_waitUntilAndExecute;

        [_x] spawn FUNC(addUnitEventHandlers);
        GVAR(nextId) = GVAR(nextId) + 1;
        _x setVariable [QGVARMAIN(isInitialized), true, true];
        _justInitialized = true;
      };
      // Re-include units that have become player-controlled again (e.g., reconnected players)
      private _isExcluded = _x getVariable [QGVARMAIN(exclude), false];
      if (_isExcluded && {isPlayer _x}) then {
        _x setVariable [QGVARMAIN(exclude), false];
        _isExcluded = false;
      };
      if (!_justInitialized && {!_isExcluded}) then {
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
        private _unitGroup = group _x;

        private _unitData = [
          (_x getVariable QGVARMAIN(id)), //1
          _pos, //2
          round getDir _x, //3
          _lifeState, //4
          BOOL((vehicle _x) isNotEqualTo _x),  //5
          if (alive _x) then {name _x} else {""}, //6
          BOOL(isPlayer _x), //7
          _unitRole, //8
          GVAR(captureFrameNo), // frame 9
          if (!isNil "ace_medical_status_fnc_hasStableVitals") then {BOOL([_x] call ace_medical_status_fnc_hasStableVitals)} else {true}, // 10
          if (!isNil "ace_medical_status_fnc_isBeingDragged") then {BOOL([_x] call ace_medical_status_fnc_isBeingDragged)} else {false}, // 11
          (getPlayerScores _x) joinString ",", // scores 12
          _x call CBA_fnc_vehicleRole, // vehicle role 13
          if (!isNull objectParent _x) then {(objectParent _x) getVariable [QGVARMAIN(id), -1]} else {-1}, // 14
          stance _x, // 15
          groupID _unitGroup, // 16 group name (dynamic)
          str side _unitGroup // 17 side (dynamic)
        ];

        if (_x getVariable ["unitData", []] isNotEqualTo _unitData) then {
          [":NEW:SOLDIER:STATE:", _unitData] call EFUNC(extension,sendData);
          _x setVariable [QGVARMAIN(unitData), _unitData];
        };
      };
      false
    } count (allUnits + allDeadMen);

    {
      private _justInitialized = false;
      if !(_x getVariable [QGVARMAIN(isInitialized), false]) then {
        _vehType = typeOf _x;
        _class = _vehType call FUNC(getClass);
        private _toExcludeKind = false;
        if (parseSimpleArray EGVAR(settings,excludeKindFromRecord) isNotEqualTo []) then {
          private _vic = _x;
          {
            if (_vic isKindOf _x) exitWith {
              _toExcludeKind = true;
            };
          } forEach (parseSimpleArray EGVAR(settings,excludeKindFromRecord));
        };
        private _toExcludeClass = false;
        if (parseSimpleArray EGVAR(settings,excludeClassFromRecord) isNotEqualTo []) then {
          {
            if (typeOf _vic == _x) exitWith {
              _toExcludeClass = true;
            };
          } forEach (parseSimpleArray EGVAR(settings,excludeClassFromRecord));
        };
        if ((_class isEqualTo "unknown") || _toExcludeKind || _toExcludeClass) exitWith {
          LOG(ARR2("WARNING: vehicle is defined as 'unknown' or exclude:",_vehType));
          _x setVariable [QGVARMAIN(isInitialized), true, true];
          _x setVariable [QGVARMAIN(exclude), true, true];
        };

        _x setVariable [QGVARMAIN(id), GVAR(nextId), true];

        private _newVehicleData = [
          GVAR(captureFrameNo), //1
          GVAR(nextId), //2
          _class, //3
          getText (configFile >> "CfgVehicles" >> _vehType >> "displayName"), //4
          typeOf _x, //5
          format ["%1", [_x] call BIS_fnc_getVehicleCustomization] //6
        ];
        _x setVariable [QGVARMAIN(newVehicleData), _newVehicleData];

        [
          {missionNamespace getVariable [QEGVAR(database,dbValid), false]},
          {[":NEW:VEHICLE:", _this] call EFUNC(extension,sendData);},
          _newVehicleData,
          30
        ] call CBA_fnc_waitUntilAndExecute;
        [_x] spawn FUNC(addUnitEventHandlers);
        GVAR(nextId) = GVAR(nextId) + 1;
        _x setVariable [QGVARMAIN(vehicleClass), _class];
        _x setVariable [QGVARMAIN(isInitialized), true, true];
        _justInitialized = true;
      };
      if (!_justInitialized && {!(_x getVariable [QGVARMAIN(exclude), false])}) then {
        private _crew = [];
        {
          if (_x getVariable [QGVARMAIN(isInitialized), false]) then {
            _crew pushBack (_x getVariable QGVARMAIN(id));
          }; false
        } count (crew _x);
        _pos = getPosASL _x;

        ([_x, [0], true] call CBA_fnc_turretDir) params ["_turretAz", "_turretEl"];
        private _vehicleData = [
          (_x getVariable QGVARMAIN(id)), //1
          _pos, //2
          round getDir _x, //3
          BOOL(alive _x), //4
          _crew, //5
          GVAR(captureFrameNo), // 6
          fuel _x, // 7
          damage _x, // 8
          isEngineOn _x, // 9
          (locked _x) >= 2, // 10
          side _x, // 11
          vectorDir _x, // 12
          vectorUp _x, // 13
          _turretAz, // 14
          _turretEl // 15
        ];

        private _ocapId = _vehicleData select 0;

        // Stop tracking parachutes/ejection seats that are empty or dead
        if ((_x getVariable [QGVARMAIN(vehicleClass), ""]) isEqualTo "parachute" && {!((alive _x) && {_crew isNotEqualTo []})}) then {
          _vehicleData set [3, 0];
          [":NEW:VEHICLE:STATE:", _vehicleData] call EFUNC(extension,sendData);
          _x setVariable [QGVARMAIN(exclude), true, true];
          GVAR(trackedVehicles) deleteAt _ocapId;
        } else {
          [":NEW:VEHICLE:STATE:", _vehicleData] call EFUNC(extension,sendData);
          GVAR(trackedVehicles) set [_ocapId, [_x, _pos, round getDir _x, side _x, vectorDir _x, vectorUp _x]];
        };
      };
      false
    } count vehicles;

    // Detect disappeared vehicles (deleted/garbage-collected) and send final dead state
    private _toRemove = [];
    {
      (GVAR(trackedVehicles) get _x) params ["_obj", "_lastPos", "_lastDir", "_lastSide", "_lastVectorDir", "_lastVectorUp"];
      if (isNull _obj) then {
        [":NEW:VEHICLE:STATE:", [
          _x, _lastPos, _lastDir, 0, [], GVAR(captureFrameNo),
          0, 1, false, false, _lastSide, _lastVectorDir, _lastVectorUp, 0, 0
        ]] call EFUNC(extension,sendData);
        _toRemove pushBack _x;
      };
    } forEach (keys GVAR(trackedVehicles));
    { GVAR(trackedVehicles) deleteAt _x } forEach _toRemove;

    if (GVARMAIN(isDebug)) then {
      private _logStr = format[localize LSTRING(FrameProcessedIn), GVAR(captureFrameNo), diag_tickTime - _loopStart];
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
