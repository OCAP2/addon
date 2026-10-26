/* ----------------------------------------------------------------------------
FILE: fnc_resetRecording.sqf

FUNCTION: OCAP_recorder_fnc_resetRecording

Description:
  Resets the recording state once a recording was exported or discarded, so
  a new recording can start in the same mission. The next start registers a
  new mission with the extension.

Parameters:
  None

Returns:
  Nothing

Public:
  No
---------------------------------------------------------------------------- */
#include "script_component.hpp"

GVAR(captureFrameNo) = 0;
publicVariable QGVAR(captureFrameNo);
GVAR(startTime) = nil;
// Clients watch startTime to know a new recording began and their snapshot chain restarted.
publicVariable QGVAR(startTime);
GVAR(playerSnapshotState) = createHashMap;
GVAR(zeusByUid) = createHashMap;
GVAR(zeusLastCamera) = createHashMap;
GVAR(zeusControlledUnits) = createHashMap;
GVAR(zeusPingLast) = createHashMap;
// These trackers survive export, but their entity ids belong to this recording.
GVAR(serviceBaseline) = createHashMap;
GVAR(serviceSessions) = createHashMap;
GVAR(serviceRearmSeen) = createHashMap;
GVAR(staticWeaponSnapshot) = createHashMap;
GVAR(staticDisassembleClaims) = [];
GVAR(staticWeaponSeen) = createHashMap;
{
  _x setVariable [QGVARMAIN(isInitialized), nil];
  _x setVariable [QGVARMAIN(exclude), nil];
  _x setVariable [QGVARMAIN(id), nil];
  _x setVariable [QGVARMAIN(unitType), nil];
  _x setVariable [QGVAR(lastZeusCuratorId), nil];
  _x setVariable [QGVAR(zeusId), nil];
} count (allUnits + allDeadMen + vehicles);
GVAR(nextId) = 0;
EGVAR(extension,sessionReady) = false;
