// This function will receive an existing projectile or submunition and add the rest of the projectile event handlers.
// These state handlers will track changes in bullet trajectory and its impact on nearby units.
#include "script_component.hpp"
params ["_projectile"];

if (isNil "_projectile") exitWith {
  WARNING("Projectile EHs: _projectile is nil");
};

// Projectile data array indices:
// 14: positions
// 16: hitParts
// 17: sim
// 18: isSub

// first, we need to verify simtype & whether this was a submunition or not.
// if this is NOT a deployed submunition itself but the simType of the ammo is "ShotSubmunition", then we need to skip the Deleted EH and leave the Deleted registration to the submunition itself. This will ensure we're tracking start to finish multiple actual projectiles from things like shotguns, cluster artillery, mixed-belt machineguns, etc.
private _data = _projectile getVariable QGVARMAIN(projectileData);
if (
  (_data select 17) isEqualTo "ShotSubmunition" &&
  {(_data select 18) isEqualTo false}
) exitWith {};

// HitExplosion
// Tracks a detonation of an explosive round, including the recipient and any nearby units who took damage.
_projectile addEventHandler ["HitExplosion", {
	params ["_projectile", "_hitEntity", "_projectileOwner", "_hitThings"];
  TRACE_4("HitExplosion",_projectile,_hitEntity,_projectileOwner,_hitThings);

  // ignore things like walls, buildings, ground
  if (isNull _hitEntity) exitWith {};

  // skip unitialized hit entities
  private _hitOcapId = _hitEntity getVariable [QGVARMAIN(id), -1];
  if (_hitOcapId isEqualTo -1) exitWith {};

  // skip if no components were hit
  if (count _hitThings isEqualTo 0) exitWith {};

  private _data = _projectile getVariable QGVARMAIN(projectileData);

  // many hit components for these events, so we'll sort them by radius (_x#3) largest to smallest and keep the top 5
  private _hitThings = _hitThings apply {[_x#3, _x#2]};
  _hitThings sort true;
  _hitThings = _hitThings select [0, 5 min (count _hitThings)];
  // add data, _x#1 will be the component name
  (_data select 16) pushBack [
    _hitOcapId,
    _hitThings apply {_x#1},
    (getPosASL _projectile) joinString ",",
    EGVAR(recorder,captureFrameNo)
  ];
  // add pos
  (_data select 14) pushBack [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    (getPosASL _projectile) joinString ","
  ];
}];

// HitPart
// Tracks a projectile impact with a vehicle/unit part.
_projectile addEventHandler ["HitPart", {
	params ["_projectile", "_hitEntity", "_projectileOwner", "_pos", "_velocity", "_normal", "_component", "_radius" ,"_surfaceType"];
  TRACE_4("HitPart",_hitEntity,_component,_radius,_surfaceType);

  // ignore things like walls, buildings, ground
  if (isNull _hitEntity) exitWith {};

  // skip unitialized hit entities
  private _hitOcapId = _hitEntity getVariable [QGVARMAIN(id), -1];
  if (_hitOcapId isEqualTo -1) exitWith {};

  // skip if no components were hit
  if (count _hitThings isEqualTo 0) exitWith {};

  private _data = _projectile getVariable QGVARMAIN(projectileData);

  // add hit data
  (_data select 16) pushBack [
    _hitOcapId,
    _component,
    (getPosASL _projectile) joinString ",",
    EGVAR(recorder,captureFrameNo)
  ];
  // add pos
  (_data select 14) pushBack [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    _pos joinString ","
  ];
}];

// Deflected
// Tracks a projectile impact with an object that caused it to ricochet. We can save the position it was at.
_projectile addEventHandler ["Deflected", {
	params ["_projectile", "_pos", "_velocity", "_hitObject"];
  TRACE_4("Deflected",_projectile,_pos,_velocity,_hitObject);

  private _data = _projectile getVariable QGVARMAIN(projectileData);
  // just log position
  (_data select 14) pushBack [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    _pos joinString ","
  ];
}];

// END EHs

// Explode
// Tracks a projectile that detonated, either by a script or by the game. We can save the position it was at.
_projectile addEventHandler ["Explode", {
	params ["_projectile", "_pos", "_velocity"];
  TRACE_3("Explode",_projectile,_pos,_velocity);

  private _data = _projectile getVariable QGVARMAIN(projectileData);
  // just log position
  (_data select 14) pushBack [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    _pos joinString ","
  ];
}];

// Deleted
// Tracks a projectile that was deleted, either by a script or by the game. The final processing call that'll send data to the server for processing.
_projectile addEventHandler ["Deleted", {
	params ["_projectile"];
  private _data = _projectile getVariable QGVARMAIN(projectileData);
  (_data select 14) pushBack [
    diag_tickTime,
    EGVAR(recorder,captureFrameNo),
    (getPosASL _projectile) joinString ","
  ];
  TRACE_1("Projectile data",_data);
  [QGVARMAIN(handleFiredManData), [_data]] call CBA_fnc_serverEvent;
}];

// Periodic position sampling for non-bullet projectiles (runs on owning client)
if ((_data select 17) isNotEqualTo "shotBullet") then {
  [{
    params ["_args", "_handle"];
    _args params ["_projectile"];
    if (isNull _projectile) exitWith {
      [_handle] call CBA_fnc_removePerFrameHandler;
    };
    private _data = _projectile getVariable QGVARMAIN(projectileData);
    (_data select 14) pushBack [
      diag_tickTime,
      EGVAR(recorder,captureFrameNo),
      (getPosASL _projectile) joinString ","
    ];
  }, EGVAR(settings,frameCaptureDelay), [_projectile]] call CBA_fnc_addPerFrameHandler;
};

TRACE_1("Finished applying EH",_projectile);
true
