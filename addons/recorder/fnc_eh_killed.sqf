/* ----------------------------------------------------------------------------
FILE: fnc_eh_killed.sqf

FUNCTION: OCAP_recorder_fnc_eh_killed

Description:
  Tracks when a unit is killed. This is the code triggered by the <OCAP_EH_EntityKilled> mission event handler.

Parameters:
  _unit - Object the event handler is assigned to. [Object]
  _killer - Object that killed the unit. [Object]
  _instigator - Person who pulled the trigger. [Object]
  _useEffects - same as useEffects in setDamage alt syntax. [Bool]

Returns:
  Nothing

Examples:
  > call FUNC(eh_killed);

Public:
  No

Author:
  Dell, IndigoFox, Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {};

params ["_victim", "_killer", "_instigator"];

// Skip parachutes and ejection seats - these generate noise like "Ejection Seat destroyed by Ejection Seat"
if ((_victim getVariable [QGVARMAIN(vehicleClass), ""]) isEqualTo "parachute") exitWith {};

// Skip disconnected players - engine kills the unit on disconnect, which is not a real death
if (_victim getVariable [QGVARMAIN(exclude), false]) exitWith {};

if !(_victim getvariable [QGVARMAIN(isKilled),false]) then {
  _victim setvariable [QGVARMAIN(isKilled),true];

  [_victim, _killer, _instigator] spawn {
    params ["_victim", "_killer", "_instigator"];

    private _killedFrame = GVAR(captureFrameNo);

    // allow some time for last-fired variable on killer to be updated
    sleep GVAR(frameCaptureDelay);

    if (_killer == _victim && owner _victim != 2 && EGVAR(settings,preferACEUnconscious) && isClass(configFile >> "CfgPatches" >> "ace_medical_status")) then {
      private _time = diag_tickTime;
      [_victim, {
        _this setVariable ["ace_medical_lastDamageSource", (_this getVariable "ace_medical_lastDamageSource"), 2];
      }] remoteExec ["call", _victim];
      waitUntil {diag_tickTime - _time > 10 || !(isNil {_victim getVariable "ace_medical_lastDamageSource"})};
      _killer = _victim getVariable ["ace_medical_lastDamageSource", _killer];
    } else {
      _killer
    };

    if (isNull _instigator) then {
      _instigator = [_victim, _killer] call FUNC(getInstigator);
    };

    // [GVAR(captureFrameNo), "killed", _victimId, ["null"], -1];
    private _victimId = _victim getVariable [QGVARMAIN(id), -1];
    if (_victimId == -1) exitWith {};
    private _eventData = [_killedFrame, "killed", _victimId, ["null"], -1];

    if (!isNull _instigator) then {
      _killerId = _instigator getVariable [QGVARMAIN(id), -1];
      if (_killerId == -1) exitWith {};

      private _lastDamageAmmo = _victim getVariable [QGVARMAIN(lastDamageAmmo), ""];
      private _eventText = [_instigator, _lastDamageAmmo] call FUNC(getEventWeaponText);

      private _lastFired = _instigator getVariable [QGVARMAIN(lastFired), "N/A"];
      OCAPEXTLOG(ARR6("KILL_DEBUG",name _victim,name _instigator,_lastDamageAmmo,_lastFired,_eventText));
      private _killerInfo = [];
      // if (_instigator isKindOf "CAManBase") then {
        _killerInfo = [
          _killerId,
          _eventText
        ];
      // } else {
      //   _killerInfo = [_killerId];
      // };

      private _killDistance = round(_instigator distance _victim);

      _eventData = [
        _killedFrame,
        "killed",
        _victimId,
        _killerInfo,
        _killDistance
      ];

      if (GVARMAIN(isDebug)) then {
        OCAPEXTLOG(ARR4("KILLED EVENT",_killedFrame,_victimId,_killerId));
      };

      [":KILL:", [
        _killedFrame,
        _victimId,
        _killerId,
        _eventText,
        _killDistance
      ]] call EFUNC(extension,sendData);
    };
  };
};
