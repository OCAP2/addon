#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {
  TRACE_1("Saving events is disabled", SHOULDSAVEEVENTS);
  false;
};

// REMINDER: This is run on the owner of this object, and therefore the projectile. See fnc_eh_fired_addRootEH.sqf.
// This could be the server or HC (or even player!) in the case of AI, or a player themselves.

params ["_firer", "_weapon", "_muzzle", "_mode", "_ammo", "_magazine", "_projectile", "_vehicle"];

if (isNil "_projectile") exitWith {
  TRACE_2("Projectile is nil", name _firer, _weapon);
  false;
};

// get ocap id of firer
private _firerOcapId = _firer getVariable [QGVARMAIN(id), -1];
if (_firerOcapId isEqualTo -1) exitWith {
  TRACE_2("Firer ocap id is -1", name _firer, _weapon);
  false;
};

// get ocap id of vehicle
private _vehicleOcapId = _vehicle getVariable [QGVARMAIN(id), -1];
if (_vehicleOcapId isEqualTo -1) then {
  _vehicleOcapId = _firerOcapId;
};

// get vehicle role
private _vehicleRole = assignedVehicleRole _firer;
if (count _vehicleRole isEqualTo 0) then {
  _vehicleRole = "";
} else {
  _vehicleRole = _vehicleRole select 0;
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


// set variables
// firedAt: refers to timing, i.e. frame number and unixNano timestamp
// firedBy: shooter info
// positions: each registered point of the projectile's path
// firedWith: weapon and ammo info
_projectile setVariable [QGVARMAIN(dataHash), createHashMapFromArray [
  ["firedFrame", EGVAR(recorder,captureFrameNo)],
  ["firedTime", [":TIMESTAMP:"] call FUNC(sendData)],
  ["firerID", _firerOcapId],
  ["vehicleID", _vehicleOcapId],
  ["vehicleRole", _vehicleRole],
  ["remoteControllerID", _remoteControllerOcapId],
  ["weapon", _weapon],
  ["weaponDisplay", getText(configFile >> "CfgWeapons" >> _weapon >> "displayName")],
  ["muzzle", _muzzle],
  ["muzzleDisplay", _muzzleDisplay],
  ["magazine", _magazine],
  ["magazineDisplay", getText(configFile >> "CfgMagazines" >> _magazine >> "displayName")],
  ["ammo", _ammo],
  ["fireMode", _mode],
  ["positions", [
    [
      [":TIMESTAMP:"] call FUNC(sendData),
      EGVAR(recorder,captureFrameNo),
      (getPosASL _projectile) joinString ","
    ]
  ]],
  ["initialVelocity",
    (velocity _projectile) joinString ","
  ],
  ["hitParts", []],
  ["sim", getText(configFile >> "CfgAmmo" >> _ammo >> "simulation")],
  ["isSub", false]
]];


// the simulation type of this ammo will determine how we handle it.
// "ShotGrenade" // M67
// "ShotRocket" // S-8
// "ShotMissile" // R-27
// "ShotShell" // VOG-17M, HE40mm
// "ShotMine" // Satchel charge
// "ShotIlluminating" // 40mm_green Flare
// "ShotSmokeX"; // M18 Smoke
// "ShotCM" // Plane flares
// "ShotSubmunition" // Hind minigun, cluster artillery

// carryover variables to submunitions
if (getText(configFile >> "CfgAmmo" >> _ammo >> "simulation") isEqualTo "ShotSubmunition") then {
  _projectile addEventHandler ["SubmunitionCreated", {
    params ["_projectile", "_submunitionProjectile"];
    _submunitionProjectile setVariable [QGVARMAIN(dataHash), _projectile getVariable QGVARMAIN(dataHash)];
    private _hash = _submunitionProjectile getVariable QGVARMAIN(dataHash);
    _hash set ["isSub", true];
    (_hash get "positions") pushBack [
        [":TIMESTAMP:"] call FUNC(sendData),
        EGVAR(recorder,captureFrameNo),
        getPosASL _submunitionProjectile
      ];
    // add the rest of EHs to submunition
    [_submunitionProjectile] call FUNCMAIN(addBulletEH);
  }];
} else {
  // add the rest of EHs to projectile
  [_projectile] call FUNCMAIN(addBulletEH);
};

true;
