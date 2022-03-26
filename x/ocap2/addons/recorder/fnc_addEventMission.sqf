/* ----------------------------------------------------------------------------
Script: ocap_fnc_addEventMission

Description:
  Used for applying mission event handlers.

  * Applied during initialization of OCAP2 in <ocap_fnc_init>.

Parameters:
  None

Returns:
  Nothing

Examples:
  --- Code
  call ocap_fnc_addEventMission;
  ---

Public:
  No

Author:
  IndigoFox, Dell
---------------------------------------------------------------------------- */
#include "script_component.hpp"

addMissionEventHandler["HandleDisconnect", {
  _this call ocap_fnc_eh_disconnected;
}];

addMissionEventHandler["PlayerConnected", {
  _this call ocap_fnc_eh_connected;
}];

addMissionEventHandler ["EntityKilled", {
  _this call ocap_fnc_eh_killed;
}];

addMissionEventHandler ["EntityRespawned", {
  params ["_entity", "_corpse"];

  // Reset unit back to normal
  _entity setvariable ["ocapIsKilled", false];

  // Stop tracking old unit
  if (_corpse getVariable [QGVARMAIN(isInitialized), false]) then {
    _corpse setVariable [QGVARMAIN(exclude), true];

    [_entity, true] spawn ocap_fnc_addEventHandlers;
  };
}];

if (isClass (configFile >> "CfgPatches" >> "ace_explosives")) then {
  call ocap_fnc_trackAceExplPlace;
};

addMissionEventHandler ["MPEnded", {
  if (EGVAR(settings,saveMissionEnded)) then {
    ["Mission ended automatically"] call FUNC(exportData);
  };
}];

// Add event saving markers
call ocap_fnc_handleMarkers;

// Custom event handler with key "ocap2_customEvent"
// Used for showing custom events in playback events list
EGVAR(listener,customEvent) = [QGVARMAIN(customEvent), {
  _this call FUNC(handleCustomEvent);
}] call CBA_fnc_addEventHandler;

// Custom event handler with key "ocap2_exportData"
EGVAR(listener,exportData) = [QGVARMAIN(exportData), {
  _this call FUNC(exportData);
}] call CBA_fnc_addEventHandler;
