/* ----------------------------------------------------------------------------
FILE: fnc_projectileMonitors.sqf

FUNCTION: OCAP_recorder_fnc_projectileMonitors

Description:
  This initializes projectile monitoring for the purposes of moving non-bullet projectile markers across the map during playback as well as to display them on the in-game map while <OCAP_isDebug> is true.

  On clients, it will create a "Draw" UI event handler to display both fire-lines representing bullets and markers representing non-bullet projectiles. It will also create an event handler used by the server in <OCAP_recorder_fnc_eh_firedMan> to integrate new projectiles to the array being procesed by the "Draw" handler.

  On the server, it will initialize <OCAP_recorder_liveMissiles> and <OCAP_recorder_liveGrenades>. These are watch arrays that are used to track the position of non-bullet projectiles and update the extension with their positions as they travel. This causes the effect of a 'moving marker' during playback.

Parameters:
  None

Returns:
  Nothing

Example:
  > call FUNC(projectileMonitors);

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

// PFH to track missiles, rockets, shells
// Variable: OCAP_recorder_liveMissiles
// Watched array of missiles, rockets, shells, and any other unaccounted projectile. Every 0.7 seconds, the position of each object in the array is updated and sent to the extension.
GVAR(liveMissiles) = [];
[{
  {
    _x params ["_projectile", "_wepString", "_firer", "_pos", "_markName", "_markTextLocal"];
    if (isNull _projectile) then {
      [QGVARMAIN(handleMarker), ["DELETED", _markName]] call CBA_fnc_localEvent;
    } else {
      _pos = getPosASL _projectile;
      GVAR(liveMissiles) set [_forEachIndex, [_projectile, _wepString, _firer, _pos, _markName, _markTextLocal]];
      [QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, _pos, "", "", "", getDir (_x#0), "", "", 1]] call CBA_fnc_localEvent;
    };
  } forEach GVAR(liveMissiles);

  GVAR(liveMissiles) = GVAR(liveMissiles) select {!isNull (_x select 0)};
}, GVAR(frameCaptureDelay)] call CBA_fnc_addPerFrameHandler;

// PFH to track grenades, flares, thrown charges
// Variable: OCAP_recorder_liveGrenades
// Watched array of grenades, flares, and thrown charges. Every 0.7 seconds, the position of each object in the array is updated and sent to the extension.
GVAR(liveGrenades) = [];
[{
  {
    _x params ["_projectile", "_wepString", "_firer", "_pos", "_markName", "_markTextLocal", "_ammoSimType"];
    if (isNull _projectile) then {
      [QGVARMAIN(handleMarker), ["DELETED", _markName]] call CBA_fnc_localEvent;
    } else {
      _pos = getPosASL _projectile;
      GVAR(liveGrenades) set [_forEachIndex, [_projectile, _wepString, _firer, _pos, _markName, _markTextLocal, _ammoSimType]];
      [QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, _pos, "", "", "", getDir (_x#0), "", "", 1]] call CBA_fnc_localEvent;
    };
  } forEach GVAR(liveGrenades);

  GVAR(liveGrenades) = GVAR(liveGrenades) select {!isNull (_x select 0)};
}, GVAR(frameCaptureDelay)] call CBA_fnc_addPerFrameHandler;



// DEBUG draws on clients

// drawLine for each bullet on map if debug active, to verify rounds are captured
// these are only added once the projectile has hit something
{
  if (!hasInterface) exitWith {};
  [] spawn {
    waitUntil {!isNull (findDisplay 12)};

    // Variable: OCAP_recorder_liveDebugBullets
    // Used by clients to draw bullet lines. Entered via <OCAP_recorder_fnc_eh_firedMan> and managed in ??
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

    // Variable: OCAP_recorder_liveDebugMagIcons
    // Used by clients to draw magazine icons of non-bullet projectiles. Entered via <OCAP_recorder_fnc_eh_firedMan> and managed in ??
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
