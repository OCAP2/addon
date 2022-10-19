/* ----------------------------------------------------------------------------
FILE: fnc_entityMonitors.sqf

FUNCTION: OCAP_recorder_fnc_entityMonitors

Description:
  While debug mode is enabled, this function will render 2D icons and text representing all entities that have been initialized by OCAP and are not being excluded from the recording.

  This is useful for debugging and verifying that the correct entities are being recorded (see <OCAP_settings_excludeClassFromRecord> and <OCAP_settings_excludeKindFromRecord>.

Parameters:
  None

Returns:
  Nothing

Examples:
  > [_hitEntity, _projectileOwner] call FUNC(eh_projectileHit);

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
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

// Variable: OCAP_entityMonitorsInitialized
// This variable on the server indicates whether or not the entity monitors have been initialized for all clients + JIP.
GVAR(entityMonitorsInitialized) = true;
