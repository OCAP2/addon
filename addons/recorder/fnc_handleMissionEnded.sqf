/* ----------------------------------------------------------------------------
FILE: fnc_handleMissionEnded.sqf

FUNCTION: OCAP_recorder_fnc_handleMissionEnded

Description:
  Called by the "MPEnded" and "Ended" mission event handlers when
  <OCAP_settings_saveMissionEnded> is true. A recording that reached
  <OCAP_settings_minMissionTime> is saved; a shorter one is discarded, so
  storage that already holds it (the websocket storage streams to the web
  server as it records) drops it instead of keeping it as partial.

  A mission script may still save a short recording on the same frame
  through <OCAP_exportData>, which bypasses the minimum, so the discard waits
  a frame and only applies to a recording still unsaved by then.

Parameters:
  None

Returns:
  Nothing

Public:
  No
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!EGVAR(settings,saveMissionEnded)) exitWith {};

if ((GVAR(captureFrameNo) * GVAR(frameCaptureDelay)) / 60 >= GVAR(minMissionTime)) exitWith {
  [nil, "Mission ended automatically"] call FUNC(exportData);
};

[{
  if (isNil QGVAR(startTime)) exitWith {}; // saved meanwhile, or never started
  [format ["the mission ended before the recording reached %1 minutes", GVAR(minMissionTime)]] call FUNC(discardRecording);
}] call CBA_fnc_execNextFrame;
