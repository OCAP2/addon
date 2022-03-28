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
  _this call FUNC(eh_disconnected);
}];

addMissionEventHandler["PlayerConnected", {
  _this call FUNC(eh_connected);
}];

addMissionEventHandler ["EntityKilled", {
  _this call FUNC(eh_killed);
}];

addMissionEventHandler ["EntityRespawned", {
  params ["_entity", "_corpse"];

  // Reset unit back to normal
  _entity setvariable [QGVARMAIN(isKilled), false];

  // Stop tracking old unit
  if (_corpse getVariable [QGVARMAIN(isInitialized), false]) then {
    _corpse setVariable [QGVARMAIN(exclude), true];

    [_entity, true] spawn FUNC(addUnitEventHandlers);
  };
}];

// Listen for global ACE Explosive placement events
if (isClass (configFile >> "CfgPatches" >> "ace_explosives")) then {
  call FUNC(aceExplosives);
};

// Listen for local ACE Throwing events, for any units owned by the server
if (isClass (configFile >> "CfgPatches" >> "ace_advanced_throwing")) then {
  call FUNC(aceThrowing);
};

addMissionEventHandler ["MPEnded", {
  if (EGVAR(settings,saveMissionEnded) && (GVAR(captureFrameNo) * GVAR(frameCaptureDelay)) >= GVAR(minMissionTime)) then {
    ["Mission ended automatically"] call FUNC(exportData);
  };
}];

addMissionEventHandler ["Ended", {
  if (EGVAR(settings,saveMissionEnded) && (GVAR(captureFrameNo) * GVAR(frameCaptureDelay)) >= GVAR(minMissionTime)) then {
    ["Mission ended automatically"] call FUNC(exportData);
  };
}];

// Add event saving markers
call FUNC(handleMarkers);

// Custom event handler with key "ocap2_customEvent"
// Used for showing custom events in playback events list
EGVAR(listener,customEvent) = [QGVARMAIN(customEvent), {
  _this call FUNC(handleCustomEvent);
}] call CBA_fnc_addEventHandler;

// Custom event handler with key "ocap2_record"
// This will START OR RESUME recording if not already.
EGVAR(listener,exportData) = [QGVARMAIN(record), {
  call FUNC(startRecording);
}] call CBA_fnc_addEventHandler;

// Custom event handler with key "ocap2_pause"
// This will PAUSE recording
EGVAR(listener,exportData) = [QGVARMAIN(pause), {
  GVAR(recording) = false;
  publicVariable QGVAR(recording);
}] call CBA_fnc_addEventHandler;

// Custom event handler with key "ocap2_exportData"
// This will export the mission immediately regardless of restrictions.
// params ["_side", "_message", "_tag"];
EGVAR(listener,exportData) = [QGVARMAIN(exportData), {
  _this set [3, true];
  _this call FUNC(exportData);
}] call CBA_fnc_addEventHandler;
