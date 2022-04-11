#include "script_component.hpp"

// DEBUG draws on clients
{
  if (!hasInterface) exitWith {};
  [] spawn {
    waitUntil {!isNull (findDisplay 12)};
    GVAR(liveDebugBullets) = [];
    disableSerialization;
    (findDisplay 12 displayCtrl 51) ctrlAddEventHandler ["Draw", {
      if (GVARMAIN(isDebug)) then {
        {
          // _x params ["_startPos", "_endPos", "_color", "_timeHit"];
          (_this#0) drawIcon [
            ["iconMan"] call BIS_fnc_textureVehicleIcon, // Custom images can also be used: getMissionPath "\myFolder\myIcon.paa"
            [side group _x] call BIS_fnc_sideColor,
            getPos _x,
            1,
            1,
            getDir _x,
            name _x,
            0,
            0.03,
            "PuristaLight",
            "center"
          ];
        } forEach (allUnits + vehicles) select {
          _x getVariable [QGVARMAIN(isInitialized), false] &&
          _x getVariable [QGVARMAIN(exclude), true]
        };
      };
    }];
  };
} remoteExec ["call", [0, -2] select isDedicated, true];

GVAR(entityMonitorsInitialized) = true;
