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

if (isNil QEGVAR(EH,HandleDisconnect)) then {
  addMissionEventHandler["HandleDisconnect", {
    _this call FUNC(eh_disconnected);
  }];
  OCAPEXTLOG(["Initialized HandleDisconnect EH"]);
};

if (isNil QEGVAR(EH,PlayerConnected)) then {
  addMissionEventHandler["PlayerConnected", {
    _this call FUNC(eh_connected);
  }];
  OCAPEXTLOG(["Initialized PlayerConnected EH"]);
};

if (isNil QEGVAR(EH,EntityKilled)) then {
  addMissionEventHandler ["EntityKilled", {
    _this call FUNC(eh_killed);
  }];
  OCAPEXTLOG(["Initialized EntityKilled EH"]);
};

if (isNil QEGVAR(EH,EntityRespawned)) then {
  EGVAR(EH,EntityRespawned) = addMissionEventHandler ["EntityRespawned", {
    params ["_entity", "_corpse"];

    // Reset unit back to normal
    _entity setvariable [QGVARMAIN(isKilled), false];

    // Stop tracking old unit
    if (_corpse getVariable [QGVARMAIN(isInitialized), false]) then {
      _corpse setVariable [QGVARMAIN(exclude), true];

      [_entity, true] spawn FUNC(addUnitEventHandlers);
    };
  }];
  OCAPEXTLOG(["Initialized EntityRespawned EH"]);
};

// Listen for global ACE Explosive placement events
if (isClass (configFile >> "CfgPatches" >> "ace_explosives")) then {
  if (isNil QEGVAR(listener,aceExplosives)) then {
    call FUNC(aceExplosives);
    OCAPEXTLOG(["Initialized ACE Explosives listener"]);
  };
};

// Listen for global ACE Throwing events that take place when a throwable is primed. use existing firedMan code, since identical args
if (isClass (configFile >> "CfgPatches" >> "ace_advanced_throwing")) then {
  if (isNil QEGVAR(listener,aceThrowing)) then {
    ["ace_advanced_throwing_throwFiredXEH", {_this call FUNC(eh_firedMan)}] call CBA_fnc_addEventHandler;
    OCAPEXTLOG(["Initialized ACE Throwing listener"]);
  };
};

if (isNil QEGVAR(EH,MPEnded)) then {
  EGVAR(EH,MPEnded) = addMissionEventHandler ["MPEnded", {
    if (EGVAR(settings,saveMissionEnded) && (GVAR(captureFrameNo) * GVAR(frameCaptureDelay)) >= GVAR(minMissionTime)) then {
      ["Mission ended automatically"] call FUNC(exportData);
    };
  }];
  OCAPEXTLOG(["Initialized MPEnded EH"]);
};

if (isNil QEGVAR(EH,Ended)) then {
  EGVAR(EH,Ended) = addMissionEventHandler ["Ended", {
    if (EGVAR(settings,saveMissionEnded) && (GVAR(captureFrameNo) * GVAR(frameCaptureDelay)) >= GVAR(minMissionTime)) then {
      ["Mission ended automatically"] call FUNC(exportData);
    };
  }];
  OCAPEXTLOG(["Initialized Ended EH"]);
};

// Add event saving markers
if (isNil QEGVAR(listener,markers)) then {
  call FUNC(handleMarkers);
};

// Custom event handler with key "ocap2_customEvent"
// Used for showing custom events in playback events list
if (isNil QEGVAR(listener,customEvent)) then {
  EGVAR(listener,customEvent) = [QGVARMAIN(customEvent), {
    _this call FUNC(handleCustomEvent);
  }] call CBA_fnc_addEventHandler;
  OCAPEXTLOG(["Initialized customEvent listener"]);
};

// Custom event handler with key "ocap2_record"
// This will START OR RESUME recording if not already.
if (isNil QEGVAR(listener,record)) then {
  EGVAR(listener,record) = [QGVARMAIN(record), {
    call FUNC(startRecording);
  }] call CBA_fnc_addEventHandler;
  OCAPEXTLOG(["Initialized record listener"]);
};

// Custom event handler with key "ocap2_pause"
// This will PAUSE recording
if (isNil QEGVAR(listener,pause)) then {
  EGVAR(listener,pause) = [QGVARMAIN(pause), {
    call FUNC(stopRecording);
  }] call CBA_fnc_addEventHandler;
  OCAPEXTLOG(["Initialized pause listener"]);
};

// Custom event handler with key "ocap2_exportData"
// This will export the mission immediately regardless of restrictions.
// params ["_side", "_message", "_tag"];
if (isNil QEGVAR(listener,exportData)) then {
  EGVAR(listener,exportData) = [QGVARMAIN(exportData), {
    _this set [3, true];
    _this call FUNC(exportData);
  }] call CBA_fnc_addEventHandler;
  OCAPEXTLOG(["Initialized exportData listener"]);
};
