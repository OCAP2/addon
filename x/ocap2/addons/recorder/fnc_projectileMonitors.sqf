#include "script_component.hpp"

// PFH to track bullets
GVAR(liveBullets) = [];
[{

  private _processNow = GVAR(liveBullets) select {isNull (_x#0)};
  GVAR(liveBullets) = GVAR(liveBullets) select {!isNull (_x#0)};

  // _processNow
  // for bullets that have hit something and become null, trigger FIRED events in timeline and add to clients for debug draw
  {
    _x params ["_obj", "_firerId", "_firer", "_pos"];

    [":FIRED:", [
      _firerId,
      GVAR(captureFrameNo),
      _pos
    ]] call EFUNC(extension,sendData);

    if (GVARMAIN(isDebug)) then {
      OCAPEXTLOG(ARR4("FIRED EVENT: BULLET", GVAR(captureFrameNo), _firerId, str _pos));

      // add to clients' map draw array
      private _debugArr = [getPos _firer, _pos, [side group _firer] call BIS_fnc_sideColor, cba_missionTime];
      [QGVAR(addDebugBullet), _debugArr] call CBA_fnc_globalEvent;
    };
  } forEach _processNow;

  // for bullets that still exist, update positions
  {
    _x set [3, getPosASL (_x#0)];
  } forEach GVAR(liveBullets);
}, 0.1 * GVAR(projectileMonitorMultiplier)] call CBA_fnc_addPerFrameHandler;

// PFH to track missiles, rockets, shells
GVAR(liveMissiles) = [];
[{
  private _processNow = GVAR(liveMissiles) select {isNull (_x#0)};
  GVAR(liveMissiles) = GVAR(liveMissiles) select {!isNull (_x#0)};

  // _processNow
  // for missiles that have hit something and become null, trigger FIRED events in timeline and add to clients for debug draw
  {
    _x params ["_obj", "_wepString", "_firer", "_pos", "_markName", "_markTextLocal"];
    _firer setVariable [
      QGVARMAIN(lastFired),
      getText(configFile >> "CfgMagazines" >> _magazine >> "displayName")
    ];

    if (GVARMAIN(isDebug)) then {
      OCAPEXTLOG(ARR4("FIRED EVENT: SHELL-ROCKET-MISSILE", GVAR(captureFrameNo), _firer getVariable QGVARMAIN(id), str _pos));
    };

    [{[QGVARMAIN(handleMarker), ["DELETED", _this]] call CBA_fnc_localEvent}, _markName, 10] call CBA_fnc_waitAndExecute;
  } forEach _processNow;

  // for missiles that still exist, update positions
  {
    _x params ["_obj", "_wepString", "_firer", "_pos", "_markName", "_markTextLocal"];
    _nowPos = getPosASL (_x#0);
    _x set [3, _nowPos];
    [QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, _nowPos, "", "", "", getDir (_x#0), "", "", 1]] call CBA_fnc_localEvent;
  } forEach GVAR(liveMissiles);
}, 0.1 * GVAR(projectileMonitorMultiplier)] call CBA_fnc_addPerFrameHandler;

// PFH to track grenades, flares, thrown charges
GVAR(liveGrenades) = [];
[{
  private _processNow = GVAR(liveMissiles) select {isNull (_x#0)};
  GVAR(liveMissiles) = GVAR(liveMissiles) select {!isNull (_x#0)};

  // _processNow
  // for grenades that have hit something and become null, trigger FIRED events in timeline and add to clients for debug draw
  {
    _x params ["_obj", "_magazine", "_firer", "_pos", "_markName", "_markTextLocal", "_ammoSimType"];

    if !(_ammoSimType in ["shotSmokeX", "shotIlluminating"]) then {
      _firer setVariable [
        QGVARMAIN(lastFired),
        getText(configFile >> "CfgMagazines" >> _magazine >> "displayName")
      ];
    };

    if (GVARMAIN(isDebug)) then {
      OCAPEXTLOG(ARR4("FIRED EVENT: GRENADE-FLARE-SMOKE", GVAR(captureFrameNo), _firer getVariable QGVARMAIN(id), str _pos));
    };

    [{[QGVARMAIN(handleMarker), ["DELETED", _this]] call CBA_fnc_localEvent}, _markName, 10] call CBA_fnc_waitAndExecute;
  } forEach _processNow;

  // for grenades that still exist, update positions
  {
    _x params ["_obj", "_magazine", "_firer", "_pos", "_markName", "_markTextLocal", "_ammoSimType"];
    _nowPos = getPosASL (_x#0);
    _x set [3, _nowPos];
    [QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, _nowPos, "", "", "", getDir (_x#0), "", "", 1]] call CBA_fnc_localEvent;
  } forEach GVAR(liveGrenades);
}, GVAR(frameCaptureDelay)] call CBA_fnc_addPerFrameHandler;



// DEBUG draws on clients

// drawLine for each bullet on map if debug active, to verify rounds are captured
// these are only added once the projectile has hit something
{
  if (!hasInterface) exitWith {};
  [] spawn {
    waitUntil {!isNull (findDisplay 12)};
    GVAR(liveDebugBullets) = [];
    disableSerialization;
    (findDisplay 12 displayCtrl 51) ctrlAddEventHandler ["Draw", {
      if (GVARMAIN(isDebug)) then {
        // remove bullets from display that have landed > 7 seconds ago
        GVAR(liveDebugBullets) = GVAR(liveDebugBullets) select {cba_missionTime < (_x#3) + 7};
        {
          // _x params ["_startPos", "_endPos", "_color", "_timeHit"];
          (_this#0) drawLine [
            _x#0,
            _x#1,
            _x#2
          ];
        } forEach GVAR(liveDebugBullets);
      };
    }];

    [QGVAR(addDebugBullet), {
      GVAR(liveDebugBullets) pushBack _this;
    }] call CBA_fnc_addEventHandler;
  };
} remoteExec ["call", [0, -2] select isDedicated, true];

// drawIcon for magazines/non-bullet projectiles
// these are added when fired and tracked in array
{
  if (!hasInterface) exitWith {};
  [] spawn {
    waitUntil {!isNull (findDisplay 12)};
    GVAR(liveDebugMagIcons) = [];
    disableSerialization;
    (findDisplay 12 displayCtrl 51) ctrlAddEventHandler ["Draw", {
      if (GVARMAIN(isDebug)) then {
        GVAR(liveDebugMagIcons) = GVAR(liveDebugMagIcons) select {!isNull (_x#0)};
        {
          // _x params ["_obj", "_magIcon", "_text", "_sideColor"];
          (_this#0) drawIcon [
            _x#1, // Custom images can also be used: getMissionPath "\myFolder\myIcon.paa"
            _x#3,
            getPos (_x#0),
            25,
            25,
            getDir (_x#0),
            _x#2,
            0,
            0.03,
            "PuristaLight",
            "center"
          ];
        } forEach GVAR(liveDebugMagIcons);
      };
    }];

    [QGVAR(addDebugMagIcon), {
      GVAR(liveDebugMagIcons) pushBack _this;
    }] call CBA_fnc_addEventHandler;
  };
} remoteExec ["call", [0, -2] select isDedicated, true];

GVAR(projectileMonitorsInitialized) = true;
