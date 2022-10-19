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
        [":NEW:UNIT:", [
          GVAR(captureFrameNo), //1
          GVAR(nextId), //2
          name _x, //3
          groupID (group _x), //4
          str side group _x, //5
          BOOL(isPlayer _x), //6
          roleDescription _x // 7
        ]] call EFUNC(extension,sendData);
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

        _unitData = [
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
        };
        _x setVariable [QGVARMAIN(unitData), _unitData];
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
        [":NEW:VEH:", [
          GVAR(captureFrameNo), //1
          GVAR(nextId), //2
          _class, //3
          getText (configFile >> "CfgVehicles" >> _vehType >> "displayName") //4
        ]] call EFUNC(extension,sendData);
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
