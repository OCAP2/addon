/* ----------------------------------------------------------------------------
FILE: fnc_newMission.sqf

FUNCTION: OCAP_extension_fnc_newMission

Description:
  Re-registers a new mission session with the extension after a previous
  recording was exported via fnc_exportData. Reuses the cached world and
  mission context from the initial initSession call (same mission is still running).

  The existing ExtensionCallback handler (added during initSession) will process
  the :MISSION:OK: response and set sessionReady = true.

  Called from fnc_startRecording when starting a fresh recording with
  sessionReady = false.

Parameters:
  None

Returns:
  Nothing

Public:
  No

Author:
  Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (isNil QGVAR(worldContext) || isNil QGVAR(missionContext)) exitWith {
  ERROR("Cannot re-register mission: cached world/mission context is nil. Full initSession required.");
};

INFO("Re-registering new mission with extension");
GVAR(initTimer) = diag_tickTime;
[":MISSION:START:", [GVAR(worldContext), GVAR(missionContext)], 'ocap_recorder'] call FUNC(sendData);
