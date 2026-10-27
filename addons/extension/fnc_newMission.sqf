/* ----------------------------------------------------------------------------
FILE: fnc_newMission.sqf

FUNCTION: OCAP_extension_fnc_newMission

Description:
  Registers a recording of the mission with the extension. Uses the world and
  mission context initSession cached once storage was initialized.

  The existing ExtensionCallback handler (added during initSession) will process
  the :MISSION:OK: response and set sessionReady = true, or :MISSION:FAILED:
  and leave it false. sessionPending is true until either arrives.

  Called from fnc_startRecording when starting a fresh recording with
  sessionReady = false: the first recording of the mission, or one after the
  previous recording was exported or discarded.

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
  ERROR("Cannot register mission: cached world/mission context is nil. Full initSession required.");
  GVAR(sessionPending) = false; // nothing will answer
};

INFO("Registering new mission with extension");
GVAR(initTimer) = diag_tickTime;
GVAR(sessionPending) = true;
// Echoed in :MISSION:OK: and :MISSION:FAILED:, so a late answer to an earlier
// mission's start is not taken for this one's.
GVAR(registrationToken) = format ["%1-%2", floor random 1e6, floor random 1e6];
GVAR(registrationSentAt) = diag_tickTime;
if (isNil {[":MISSION:START:", [GVAR(worldContext), GVAR(missionContext), GVAR(registrationToken)], 'ocap_recorder'] call FUNC(sendData)}) then {
  ERROR("The extension did not accept the mission; recording will not start.");
  GVAR(sessionPending) = false; // nothing will answer
};
