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
          (_this#0) drawIcon [
            (_x call {
              if (_this call CBA_fnc_isPerson) then {
                getText(configFile >> "CfgVehicleIcons" >> (getText((configOf _this) >> "icon")))
              } else {
                getText((configOf _this) >> "icon")
              };
            }),
            [side group _x] call BIS_fnc_sideColor,
            getPos _x,
            _iconSize,
            _iconSize,
            getDir _x,
            (_x call {
              if (_this call CBA_fnc_isPerson) then {name _this} else {getText(configOf _this >> "displayName")}
            }),
            1,
            0.02,
            "TahomaB",
            "center"
          ];
        } forEach ((allUnits + vehicles) select {
          _x getVariable [QGVARMAIN(isInitialized), false] &&
          !(_x getVariable [QGVARMAIN(exclude), false]) &&
          not (!alive _x || isNull _x || objectParent _x isNotEqualTo objNull)
        });
      };
    }];
  };
} remoteExec ["call", [0, -2] select isDedicated, true];

GVAR(entityMonitorsInitialized) = true;
