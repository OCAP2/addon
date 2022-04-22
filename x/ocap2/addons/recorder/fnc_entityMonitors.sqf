#include "script_component.hpp"

// DEBUG draws on clients
{
  if (!hasInterface) exitWith {};
  [] spawn {
    waitUntil {!isNull (findDisplay 12)};
    disableSerialization;
    (findDisplay 12 displayCtrl 51) ctrlAddEventHandler ["Draw", {
      if (GVARMAIN(isDebug)) then {
        _sizeInMeters = 2.5;
        _iconSize = (_sizeInMeters * 0.15) * 10^(abs log (ctrlMapScale (_this#0)));
        {
          // _x params ["_startPos", "_endPos", "_color", "_timeHit"];
          if (!alive _x || isNull _x) then {continue};
          (_this#0) drawIcon [
            getText(configFile >> "CfgVehicleIcons" >> (getText((configOf _x) >> "icon"))), // Custom images can also be used: getMissionPath "\myFolder\myIcon.paa"
            [side group _x] call BIS_fnc_sideColor,
            getPos _x,
            _iconSize,
            _iconSize,
            getDir _x,
            name _x,
            1,
            0.02,
            "TahomaB",
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
