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

#include "script_component.hpp"

if (!isNil QGVAR(PFHObject)) then {
  [GVAR(PFHObject)] call CBA_fnc_deletePerFrameHandlerObject;
  GVAR(PFHObject) = nil;
} else {
  GVAR(startTime) = time;
  LOG(ARR3(__FILE__, QGVAR(capturing) + " started, time:", GVAR(startTime)));
};

GVAR(PFHObject) = [
  {
    if (!isNil {_private#0}) then {
      if (EGVAR(settings,frameCaptureDelay) != _private#0) exitWith {
        OCAPEXTLOG(ARR_3("Frame capture delay changed", _private#0, EGVAR(settings,frameCaptureDelay)));
        TRACE_3("Frame capture delay changed", _private#0, EGVAR(settings,frameCaptureDelay));
        GVAR(capturing) = false;
        [{call FUNC(startCaptureLoop)}, [], EGVAR(settings,frameCaptureDelay) + _private#0] call CBA_fnc_waitAndExecute;
      };
    };
    _frameCaptureDelay = EGVAR(settings,frameCaptureDelay);

    TRACE_2("Frame", _frameCaptureDelay);
    if (GVAR(captureFrameNo) == 10 || (GVAR(captureFrameNo) > 10 && EGVAR(settings,trackTimes) && GVAR(captureFrameNo) % EGVAR(settings,trackTimeInterval) == 0)) then {
      [] call FUNC(updateTime);
    };

    if (GVAR(captureFrameNo) % (60 / EGVAR(settings,frameCaptureDelay)) == 0) then {
      publicVariable QGVAR(captureFrameNo);
      {
        player createDiaryRecord [
          "OCAP2Info",
          [
            "Status",
            ("<font color='#CCCCCC'>Capture frame: " + QGVAR(captureFrameNo) + "</font>")
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
          GVAR(nextId), //2
          name _x, //3
          groupID (group _x), //4
          str side group _x, //5
          BOOL(isPlayer _x), //6
          roleDescription _x // 7
        ]] call EFUNC(extension,sendData);
        [_x] spawn ocap_fnc_addEventHandlers;
        GVAR(nextId) = GVAR(nextId) + 1;
        _x setVariable [QGVARMAIN(isInitialized), true];
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
        _class = _vehType call FUNC(getClass);
        _toExcludeKind = false;
        if (count (parseSimpleArray EGVAR(settings,excludeKindFromRecord)) > 0) then {
          private _vic = _x;
          {
            if (_vic isKindOf _x) exitWith {
              _toExcludeKind = true;
            };
          } forEach (parseSimpleArray EGVAR(settings,excludeKindFromRecord));
        };
        if ((_class isEqualTo "unknown") || (_vehType in (parseSimpleArray EGVAR(settings,excludeClassFromRecord))) || _toExcludeKind) exitWith {
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

    GVAR(captureFrameNo) = GVAR(captureFrameNo) + 1;
  },
  EGVAR(settings,frameCaptureDelay), // delay
  [], // args
  {
    GVAR(capturing) = true;

    { // add diary entry for clients on recording start
      [{!isNull player}, {
        player createDiaryRecord [
          "OCAP2Info",
          [
            "Status",
            "<font color='#33FF33'>OCAP2 began recording.</font>"
          ], taskNull, "", false
        ];
        player setDiarySubjectPicture [
          "OCAP2Info",
          "\A3\ui_f\data\igui\cfg\simpleTasks\types\use_ca.paa"
        ];
      }] call CBA_fnc_waitUntilAndExecute;
    } remoteExecCall ["call", 0, true];
  }, // code, executed when added
  {
    GVAR(capturing) = false;

    { // add diary entry for clients on recording start
      [{!isNull player}, {
        player createDiaryRecord [
          "OCAP2Info",
          [
            "Status",
            "<font color='#33FF33'>OCAP2 stopped recording.</font>"
          ], taskNull, "", false
        ];
        player setDiarySubjectPicture [
          "OCAP2Info",
          "\A3\ui_f\data\igui\cfg\simpleTasks\types\use_ca.paa"
        ];
      }] call CBA_fnc_waitUntilAndExecute;
    } remoteExecCall ["call", 0, true];
  }, // code, executed when removed
  {GVAR(capturing)}, // if true, execute PFH cycle
  {!GVAR(capturing) || !GVARMAIN(enabled)}, // if true, delete object
  ["_frameCaptureDelay"]
] call CBA_fnc_createPerFrameHandlerObject;
























waitUntil{(count(allPlayers) >= EGVAR(settings,minPlayerCount))};
