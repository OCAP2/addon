// Non-bullet projectile event handler setup (runs on projectile owner)
// Streams position/hit data to the server instead of accumulating locally.
// See fnc_eh_fired_clientBullet.sqf for the bullet-only (client-side) equivalent.
#include "script_component.hpp"
params ["_projectile", "_tempKey"];

if (isNil "_projectile") exitWith {
  WARNING("ClientProjectile EHs: _projectile is nil");
};

// Shared sent flag — prevents duplicate done signals between Deleted EH and PFH.
// Array passed by reference: Deleted EH reads via projectile variable, PFH via args.
private _state = [false];
_projectile setVariable [QGVARMAIN(projectileState), _state];
_projectile setVariable [QGVARMAIN(projectileTempKey), _tempKey];

// HitExplosion — explosive detonation near entities
_projectile addEventHandler ["HitExplosion", {
  params ["_projectile", "_hitEntity", "_projectileOwner", "_hitThings"];
  TRACE_4("HitExplosion",_projectile,_hitEntity,_projectileOwner,_hitThings);

  if (isNull _hitEntity) exitWith {};
  private _hitOcapId = _hitEntity getVariable [QGVARMAIN(id), -1];
  if (_hitOcapId isEqualTo -1) exitWith {};
  if (count _hitThings isEqualTo 0) exitWith {};

  // Sort by radius (largest first), keep top 5, extract component names
  private _hitThings = _hitThings apply {[_x#3, _x#2]};
  _hitThings sort true;
  _hitThings = _hitThings select [0, 5 min (count _hitThings)];

  private _tempKey = _projectile getVariable QGVARMAIN(projectileTempKey);
  [QGVARMAIN(handleProjectileHit), [_tempKey, [
    _hitOcapId,
    _hitThings apply {_x#1},
    (getPosASL _projectile) joinString ",",
    EGVAR(recorder,captureFrameNo)
  ], [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    (getPosASL _projectile) joinString ","
  ]]] call CBA_fnc_serverEvent;
}];

// HitPart — direct projectile impact on vehicle/unit part
_projectile addEventHandler ["HitPart", {
  params ["_projectile", "_hitEntity", "_projectileOwner", "_pos", "_velocity", "_normal", "_component", "_radius", "_surfaceType"];
  TRACE_4("HitPart",_hitEntity,_component,_radius,_surfaceType);

  if (isNull _hitEntity) exitWith {};
  private _hitOcapId = _hitEntity getVariable [QGVARMAIN(id), -1];
  if (_hitOcapId isEqualTo -1) exitWith {};

  private _tempKey = _projectile getVariable QGVARMAIN(projectileTempKey);
  [QGVARMAIN(handleProjectileHit), [_tempKey, [
    _hitOcapId,
    _component,
    (getPosASL _projectile) joinString ",",
    EGVAR(recorder,captureFrameNo)
  ], [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    _pos joinString ","
  ]]] call CBA_fnc_serverEvent;
}];

// Deflected — ricochet, log position
_projectile addEventHandler ["Deflected", {
  params ["_projectile", "_pos", "_velocity", "_hitObject"];
  TRACE_4("Deflected",_projectile,_pos,_velocity,_hitObject);

  private _tempKey = _projectile getVariable QGVARMAIN(projectileTempKey);
  [QGVARMAIN(handleProjectilePos), [_tempKey, [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    _pos joinString ","
  ]]] call CBA_fnc_serverEvent;
}];

// Explode — detonation, log position
_projectile addEventHandler ["Explode", {
  params ["_projectile", "_pos", "_velocity"];
  TRACE_3("Explode",_projectile,_pos,_velocity);

  private _tempKey = _projectile getVariable QGVARMAIN(projectileTempKey);
  [QGVARMAIN(handleProjectilePos), [_tempKey, [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    _pos joinString ","
  ]]] call CBA_fnc_serverEvent;
}];

// Deleted — send done signal to server
_projectile addEventHandler ["Deleted", {
  params ["_projectile"];
  private _state = _projectile getVariable [QGVARMAIN(projectileState), [false]];
  if (_state select 0) exitWith {};
  _state set [0, true];

  private _tempKey = _projectile getVariable QGVARMAIN(projectileTempKey);
  [QGVARMAIN(handleProjectileDone), [_tempKey, [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    (getPosASL _projectile) joinString ","
  ]]] call CBA_fnc_serverEvent;
}];

// PFH — periodic position sampling + failsafe done signal
// _state passed by reference in args — survives projectile deletion
[{
  params ["_args", "_handle"];
  _args params ["_projectile", "_tempKey", "_state"];
  if (isNull _projectile) exitWith {
    if !(_state select 0) then {
      _state set [0, true];
      [QGVARMAIN(handleProjectileDone), [_tempKey]] call CBA_fnc_serverEvent;
    };
    [_handle] call CBA_fnc_removePerFrameHandler;
  };
  [QGVARMAIN(handleProjectilePos), [_tempKey, [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    (getPosASL _projectile) joinString ","
  ]]] call CBA_fnc_serverEvent;
}, EGVAR(settings,frameCaptureDelay), [_projectile, _tempKey, _state]] call CBA_fnc_addPerFrameHandler;

TRACE_1("Finished applying projectile EHs",_projectile);
true
