#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {
  TRACE_1("Saving events is disabled",SHOULDSAVEEVENTS);
  false;
};

// REMINDER: This is run on the owner of this object, and therefore the projectile. See fnc_eh_fired_addRootEH.sqf.
// This could be the server or HC (or even player!) in the case of AI, or a player themselves.

params ["_firer", "_weapon", "_muzzle", "_mode", "_ammo", "_magazine", "_projectile", "_vehicle"];

if (isNil "_projectile") exitWith {
  TRACE_2("Projectile is nil",name _firer,_weapon);
  false;
};

// get ocap id of firer
private _firerOcapId = _firer getVariable [QGVARMAIN(id), -1];
if (_firerOcapId isEqualTo -1) exitWith {
  TRACE_2("Firer ocap id is -1",name _firer,_weapon);
  false;
};

// get ocap id of vehicle
private _vehicleOcapId = _vehicle getVariable [QGVARMAIN(id), -1];
if (_vehicleOcapId isEqualTo -1) then {
  _vehicleOcapId = _firerOcapId;
};

// get vehicle role — only when FiredMan says this was a vehicle weapon,
// assignedVehicleRole can return stale data after dismount
private _vehicleRole = "";
if (!isNull _vehicle) then {
  private _role = assignedVehicleRole _firer;
  if (count _role > 0) then {
    _vehicleRole = _role select 0;
  };
};

// get controller of this unit
private _remoteControllerOcapId = (_firer getVariable ["BIS_fnc_moduleRemoteControl_owner", objNull]) getVariable [QGVARMAIN(id), -1];
if (_remoteControllerOcapId isEqualTo -1) then {
  _remoteControllerOcapId = _firerOcapId;
};

// set weapon to non preset className
_baseWeapon = [_weapon] call CBA_fnc_getNonPresetClass;
if (_baseWeapon isNotEqualTo "") then {
  _weapon = _baseWeapon;
};

// get muzzle display name
private _muzzleDisplay = getText(configFile >> "CfgWeapons" >> _weapon >> _muzzle >> "displayName");
if (_muzzleDisplay isEqualTo "") then {
  _muzzleDisplay = getText(configFile >> "CfgWeapons" >> _weapon >> "displayName");
};

// Set lastFired on firer for kill attribution — broadcast to server (owner 2)
// so the kill handler can read it regardless of which machine the firer is on
private _magDisplay = getText(configFile >> "CfgMagazines" >> _magazine >> "displayName");
private _vehicleDisplay = if (!isNull _vehicle) then {[configOf _vehicle] call BIS_fnc_displayName} else {""};
_firer setVariable [QGVARMAIN(lastFired), [_vehicleDisplay, _muzzleDisplay, _magDisplay], 2];

// Projectile data array structure:
// 0:  firedFrame
// 1:  firedTime (diag_tickTime)
// 2:  firerID
// 3:  vehicleID
// 4:  vehicleRole
// 5:  remoteControllerID
// 6:  weapon
// 7:  weaponDisplay
// 8:  muzzle
// 9:  muzzleDisplay
// 10: magazine
// 11: magazineDisplay
// 12: ammo
// 13: fireMode
// 14: positions [[tickTime, frame, "x,y,z"], ...]
// 15: initialVelocity
// 16: hitParts [[hitOcapId, component, "x,y,z", frame], ...]
// 17: sim
// 18: isSub
// 19: magazineIcon

private _data = [
  EGVAR(recorder,captureFrameNo),                                    // 0: firedFrame
  diag_tickTime,                                                     // 1: firedTime
  _firerOcapId,                                                      // 2: firerID
  _vehicleOcapId,                                                    // 3: vehicleID
  _vehicleRole,                                                      // 4: vehicleRole
  _remoteControllerOcapId,                                           // 5: remoteControllerID
  _weapon,                                                           // 6: weapon
  getText(configFile >> "CfgWeapons" >> _weapon >> "displayName"),   // 7: weaponDisplay
  _muzzle,                                                           // 8: muzzle
  _muzzleDisplay,                                                    // 9: muzzleDisplay
  _magazine,                                                         // 10: magazine
  getText(configFile >> "CfgMagazines" >> _magazine >> "displayName"), // 11: magazineDisplay
  _ammo,                                                             // 12: ammo
  _mode,                                                             // 13: fireMode
  [[diag_tickTime, EGVAR(recorder,captureFrameNo), (getPosASL _projectile) joinString ","]], // 14: positions
  (velocity _projectile) joinString ",",                             // 15: initialVelocity
  [],                                                                // 16: hitParts
  getText(configFile >> "CfgAmmo" >> _ammo >> "simulation"),         // 17: sim
  false,                                                             // 18: isSub
  getText(configFile >> "CfgMagazines" >> _magazine >> "picture")    // 19: magazineIcon
];

_projectile setVariable [QGVARMAIN(projectileData), _data];

// Handle placed objects (mines, explosives) — separate lifecycle from projectiles
if (_weapon == "put") then {
  _projectile setVariable [QGVARMAIN(detonated), false];

  // Build :NEW:PLACED: data — placedId assigned server-side (GVAR(nextId) only exists there)
  private _placedData = [
    EGVAR(recorder,captureFrameNo),                                        // 0: captureFrameNo
    -1,                                                                     // 1: placedId (assigned by server)
    typeOf _projectile,                                                     // 2: className
    _data select 11,                                                        // 3: displayName (magazineDisplay)
    (getPosASL _projectile) joinString ",",                                 // 4: position
    _firerOcapId,                                                           // 5: firerOcapId
    str (side group _firer),                                                // 6: side
    _weapon,                                                                // 7: weapon
    _data select 19                                                         // 8: magazineIcon
  ];

  [QGVARMAIN(handlePlacedData), [_placedData, _projectile]] call CBA_fnc_serverEvent;

  // Attach simplified EHs for placed object lifecycle
  _projectile addEventHandler ["HitExplosion", {
    params ["_projectile", "_hitEntity", "_projectileOwner", "_hitThings"];
    if (isNull _hitEntity) exitWith {};
    if (count _hitThings isEqualTo 0) exitWith {};
    private _hitOcapId = _hitEntity getVariable [QGVARMAIN(id), -1];
    if (_hitOcapId isEqualTo -1) exitWith {};
    private _placedId = _projectile getVariable [QGVARMAIN(placedId), -1];
    private _eventData = [
      EGVAR(recorder,captureFrameNo),                                      // 0: captureFrameNo
      _placedId,                                                            // 1: placedId
      "hit",                                                                // 2: eventType
      (getPosASL _hitEntity) joinString ",",                                // 3: position (victim pos)
      _hitOcapId                                                            // 4: hitEntityOcapId
    ];
    [QGVARMAIN(handlePlacedEvent), [_eventData]] call CBA_fnc_serverEvent;
  }];

  _projectile addEventHandler ["Explode", {
    params ["_projectile", "_pos", "_velocity"];
    if (_projectile getVariable [QGVARMAIN(detonated), true]) exitWith {};
    _projectile setVariable [QGVARMAIN(detonated), true];
    private _placedId = _projectile getVariable [QGVARMAIN(placedId), -1];
    private _eventData = [
      EGVAR(recorder,captureFrameNo),                                      // 0: captureFrameNo
      _placedId,                                                            // 1: placedId
      "detonated",                                                          // 2: eventType
      _pos joinString ","                                                   // 3: position
    ];
    [QGVARMAIN(handlePlacedEvent), [_eventData]] call CBA_fnc_serverEvent;
  }];

  _projectile addEventHandler ["Deleted", {
    params ["_projectile"];
    // Only send "deleted" if not already detonated (avoid double-send)
    if (_projectile getVariable [QGVARMAIN(detonated), true]) exitWith {};
    _projectile setVariable [QGVARMAIN(detonated), true];
    private _placedId = _projectile getVariable [QGVARMAIN(placedId), -1];
    private _eventData = [
      EGVAR(recorder,captureFrameNo),                                      // 0: captureFrameNo
      _placedId,                                                            // 1: placedId
      "deleted",                                                            // 2: eventType
      (getPosASL _projectile) joinString ","                                // 3: position
    ];
    [QGVARMAIN(handlePlacedEvent), [_eventData]] call CBA_fnc_serverEvent;
  }];
} else {
  // carryover variables to submunitions
  if ((_data select 17) isEqualTo "shotSubmunitions") then {
    _projectile addEventHandler ["SubmunitionCreated", {
      params ["_projectile", "_submunitionProjectile"];
      private _data = +(_projectile getVariable QGVARMAIN(projectileData));
      _data set [17, getText(configOf _submunitionProjectile >> "simulation")]; // actual sim type
      _data set [18, true]; // isSub = true
      (_data select 14) pushBack [
        diag_tickTime,
        EGVAR(recorder,captureFrameNo),
        (getPosASL _submunitionProjectile) joinString ","
      ];
      _submunitionProjectile setVariable [QGVARMAIN(projectileData), _data];
      // add the rest of EHs to submunition
      [_submunitionProjectile] call FUNC(eh_fired_clientBullet);
    }];
  } else {
    // add the rest of EHs to projectile
    [_projectile] call FUNC(eh_fired_clientBullet);
  };
};

true;
