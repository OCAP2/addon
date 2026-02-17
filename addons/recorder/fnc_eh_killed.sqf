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

    // Log raw EntityKilled params for debugging
    if (GVARMAIN(isDebug)) then {
      diag_log text format [
        "[OCAP] KILL_RAW: victim=%1 (%2), killer=%3 (%4), instigator=%5, lastDamageAmmo=%6",
        name _victim, typeOf _victim,
        if (isNull _killer) then {"null"} else {format ["%1 (%2)", name _killer, typeOf _killer]},
        typeOf _killer,
        if (isNull _instigator) then {"null"} else {name _instigator},
        _victim getVariable [QGVARMAIN(lastDamageAmmo), ""]
      ];
    };

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

    // Check if victim was killed by explosive ammo (mines, satchels, grenades, etc.)
    // HandleDamage EH stores the actual ammo classname on the victim.
    // For explosive ammo, override lastFired since the instigator may have fired other weapons since.
    private _lastDamageAmmo = _victim getVariable [QGVARMAIN(lastDamageAmmo), ""];
    if (_lastDamageAmmo != "" && {!isNull _instigator}) then {
      private _isExplosive = getNumber (configFile >> "CfgAmmo" >> _lastDamageAmmo >> "explosive") > 0;
      if (_isExplosive) then {
        // Derive display name from ammo config (magazine name preferred, then ammo name, then classname)
        private _ammoDisplayName = "";
        private _defaultMag = getText (configFile >> "CfgAmmo" >> _lastDamageAmmo >> "defaultMagazine");
        if (_defaultMag != "") then {
          _ammoDisplayName = getText (configFile >> "CfgMagazines" >> _defaultMag >> "displayName");
        };
        if (_ammoDisplayName == "") then {
          _ammoDisplayName = getText (configFile >> "CfgAmmo" >> _lastDamageAmmo >> "displayName");
        };
        if (_ammoDisplayName == "") then {
          _ammoDisplayName = _lastDamageAmmo;
        };

        // Skip override if instigator is in an armed turret — turret weapon attribution is correct
        private _inArmedTurret = false;
        private _veh = objectParent _instigator;
        if (!isNull _veh) then {
          {
            if ((_veh turretUnit _x) isEqualTo _instigator && {(_veh weaponsTurret _x) isNotEqualTo []}) exitWith {
              _inArmedTurret = true;
            };
          } forEach (allTurrets _veh);
        };

        if (!_inArmedTurret) then {
          if (GVARMAIN(isDebug)) then {
            diag_log text format ["[OCAP] KILL_EXPLOSIVE_OVERRIDE: ammo=%1, displayName=%2, instigator=%3", _lastDamageAmmo, _ammoDisplayName, name _instigator];
          };
          _instigator setVariable [QGVARMAIN(lastFired), ["", _ammoDisplayName, ""]];
        };
      };
    };

    // [GVAR(captureFrameNo), "killed", _victimId, ["null"], -1];
    private _victimId = _victim getVariable [QGVARMAIN(id), -1];
    if (_victimId == -1) exitWith {};
    private _eventData = [_killedFrame, "killed", _victimId, ["null"], -1];

    if (!isNull _instigator) then {
      _killerId = _instigator getVariable [QGVARMAIN(id), -1];
      if (_killerId == -1) exitWith {};

      private _eventText = [_instigator] call FUNC(getEventWeaponText);
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
        diag_log text format [
          "[OCAP] KILL_EVENT: frame=%1, victim=%2 (id=%3), killer=%4 (id=%5), weapon=%6, distance=%7, lastDamageAmmo=%8",
          _killedFrame, name _victim, _victimId, name _instigator, _killerId, _eventText, _killDistance, _lastDamageAmmo
        ];
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
