/* ----------------------------------------------------------------------------
FILE: fnc_handleMissionEnded.sqf

FUNCTION: OCAP_recorder_fnc_handleMissionEnded

Description:
  Called by the "MPEnded" and "Ended" mission event handlers. With
  <OCAP_settings_saveMissionEnded>, a recording that reached
  <OCAP_settings_minMissionTime> is saved; a shorter one is discarded, so
  storage that already holds it (the websocket storage streams to the web
  server as it records) drops it instead of keeping it as partial.

  A mission script may still save a short recording on the same frame
  through <OCAP_exportData>, which bypasses the minimum, so the discard waits
  a frame and only applies to a recording still unsaved by then.

  Whatever the setting, a mission registered with the extension whose
  capture never began is discarded: it holds nothing worth keeping. That
  includes one still registering, once the extension confirms it.

Parameters:
  None

Returns:
  Nothing

Public:
  No

Author:
  Smith
---------------------------------------------------------------------------- */
#include "script_component.hpp"

// A recording still waiting for the extension to register the mission never
// starts; see OCAP_recorder_fnc_startRecording.
GVAR(missionEnded) = true;

if (isNil QGVAR(startTime)) exitWith {
  // Registered, but paused before the capture began.
  ["the mission ended before the recording began"] call FUNC(discardRecording);
};

if (!EGVAR(settings,saveMissionEnded)) exitWith {};

if ((GVAR(captureFrameNo) * GVAR(frameCaptureDelay)) / 60 >= GVAR(minMissionTime)) exitWith {
  [nil, "Mission ended automatically"] call FUNC(exportData);
};

[{
  if (isNil QGVAR(startTime)) exitWith {}; // saved meanwhile, or never started
  [format ["the mission ended before the recording reached %1 minutes", GVAR(minMissionTime)]] call FUNC(discardRecording);
  GVAR(discardedAtEnd) = true; // a later OCAP_exportData says so
}] call CBA_fnc_execNextFrame;
