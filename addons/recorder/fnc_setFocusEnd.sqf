/* ----------------------------------------------------------------------------
FILE: fnc_setFocusEnd.sqf

FUNCTION: OCAP_recorder_fnc_setFocusEnd

Description:
  Sets the playback focus end frame. If no frame number is provided,
  uses the current capture frame. Sends :MISSION:FOCUS_END: to extension.

Parameters:
  _frameNumber - (optional) explicit frame number [Number]

Returns:
  Nothing

Examples:
  > ["OCAP_setFocusEnd"] call CBA_fnc_serverEvent;
  > ["OCAP_setFocusEnd", [850]] call CBA_fnc_serverEvent;

Public:
  No

Author:
  Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {};

params [["_frameNumber", GVAR(captureFrameNo), [0]]];

[":MISSION:FOCUS_END:", [_frameNumber]] call EFUNC(extension,sendData);
