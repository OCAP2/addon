#include "script_component.hpp"

// PFH to track missiles, rockets, shells
GVAR(liveMissiles) = [];
[{
  GVAR(liveMissiles) = GVAR(liveMissiles) select {!isNull (_x#0)};

  // for missiles that still exist, update positions
  {
    _x params ["_obj", "_wepString", "_firer", "_pos", "_markName", "_markTextLocal"];
    _nowPos = getPosASL (_x#0);
    _x set [3, _nowPos];
    [QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, _nowPos, "", "", "", getDir (_x#0), "", "", 1]] call CBA_fnc_localEvent;
  } forEach GVAR(liveMissiles);
}, 0.7] call CBA_fnc_addPerFrameHandler;

// PFH to track grenades, flares, thrown charges
GVAR(liveGrenades) = [];
[{
  GVAR(liveGrenades) = GVAR(liveGrenades) select {!isNull (_x#0)};

  // for grenades that still exist, update positions
  {
    _x params ["_obj", "_magazine", "_firer", "_pos", "_markName", "_markTextLocal", "_ammoSimType"];
    _nowPos = getPosASL (_x#0);
    _x set [3, _nowPos];
    [QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, _nowPos, "", "", "", getDir (_x#0), "", "", 1]] call CBA_fnc_localEvent;
  } forEach GVAR(liveGrenades);
}, 0.7] call CBA_fnc_addPerFrameHandler;



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
