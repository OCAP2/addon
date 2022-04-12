/* ----------------------------------------------------------------------------
Script: FUNC(addUnitEventHandlers)

Description:
  Used for applying unit-specific event handlers to units during initialization. These event handlers will trigger on the server.

  Applied during initialization of a unit in <FUNC(captureLoop)>.

Parameters:
  _entity - Object to apply event handlers to. [Object]
  _respawn - Determines if unit is initialized for the first time, or has respawned and does not need certain handlers reapplied. [Boolean, defaults to false]

Returns:
  Nothing

Examples:
  --- Code
  [_unit] spawn FUNC(addUnitEventHandlers);
  ---

Public:
  No

Author:
  IndigoFox, Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_entity", ["_respawn", false]];


// FIREDMAN
if ((_entity call BIS_fnc_objectType) # 0 == "Soldier") then {
  if (isNil {_entity getVariable QGVARMAIN(FiredManEH)}) then {
    _entity setVariable [
      QGVARMAIN(FiredManEH),
      _entity addEventHandler ["FiredMan", { _this call FUNC(eh_firedMan); }]
    ];
  };
};

// MPHIT
// if (isNil {_entity getVariable QGVARMAIN(MPHitEH)}) then {
//   _entity setVariable [
//     QGVARMAIN(MPHitEH),
//     _entity addMPEventHandler ["MPHit", { _this call FUNC(eh_hit); }]
//   ];
// };



// HITPART
[_entity, [
  "HitPart",
  {
    // https://community.bistudio.com/wiki/HitPart_Sample
    (_this select 0) params ["_target", "_shooter", "_projectile", "_position", "_velocity", "_selection", "_ammo", "_vector", "_radius", "_surfaceType", "_isDirect"];

    if (isNull _shooter) then {
    //   _shooter = [_target, _projectile] call FUNC(getInstigator);
      private _shotParents = getShotParents _projectile;
      if (count _shotParents == 1) then {
        _shooter = [_target, _shotParents#0, objNull] call FUNC(getInstigator);
      };
      if (count _shotParents == 2) then {
        _shooter = [_target, _shotParents#0, _shotParents#1] call FUNC(getInstigator);
      };
    };
    if (isNull _shooter) exitWith {};

    private _hitFrame = GVAR(captureFrameNo);

    _targetID = _target getVariable [QGVARMAIN(id), -1];
    if (_targetID == -1) exitWith {};
    _shooterId = _shooter getVariable [QGVARMAIN(id), -1];
    if (_shooterId == -1) exitWith {};

    private _eventData = [_hitFrame, "hit", _targetID, [_shooterId, getText(configOf _projectile >> "displayName")], -1];



    _wepText = format["%1x", count _this];

    private _allSelections = flatten(_this apply {_x#5});
    if (count _allSelections > 0) then {
      private _uniqueSelections = _allSelections arrayIntersect _allSelections;
      _wepText = format["%1 - %2", _wepText, _uniqueSelections joinString ","];
    };

    _wepText = format["%1 - %2", _wepText, ([_shooter] call FUNC(getEventWeaponText))];




    _projectileInfo = [
      _shooterId,
      _wepText
    ];
    _distanceInfo = round (_target distance _shooter);

    if (GVARMAIN(isDebug)) then {
      OCAPEXTLOG(ARR4("HIT EVENT", _hitFrame, _targetID, _shooterId));
    };
    _eventData = [
      _hitFrame,
      "hit",
      _targetID,
      _projectileInfo,
      _distanceInfo
    ];

    [":EVENT:", _eventData] remoteExecCall [QEFUNC(extension,sendData), 2];

  }
]] remoteExec ["addEventHandler", [0, -2] select isDedicated, true];
