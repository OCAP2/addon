/* ----------------------------------------------------------------------------
FILE: fnc_newMission.sqf

FUNCTION: OCAP_database_fnc_newMission

Description:
  Re-registers a new mission session with the extension after a previous
  recording was exported via fnc_exportData. Reuses the cached world and
  mission context from the initial initDB call (same mission is still running).

  The existing ExtensionCallback handler (added during initDB) will process
  the :MISSION:OK: response and set dbValid = true.

  Called from fnc_startRecording when starting a fresh recording with
  dbValid = false.

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
  ERROR(localize LSTRING(CannotReRegisterMission));
};

INFO(localize LSTRING(ReRegisteringMission));
GVAR(initTimer) = diag_tickTime;
[":NEW:MISSION:", [GVAR(worldContext), GVAR(missionContext)], 'ocap_recorder'] call EFUNC(extension,sendData);
