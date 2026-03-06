/* ----------------------------------------------------------------------------
FILE: fnc_setFocusStart.sqf

FUNCTION: OCAP_recorder_fnc_setFocusStart

Description:
  Sets the playback focus start frame. If no frame number is provided,
  uses the current capture frame. Sends :MISSION:FOCUS_START: to extension.

Parameters:
  _frameNumber - (optional) explicit frame number [Number]

Returns:
  Nothing

Examples:
  > ["OCAP_setFocusStart"] call CBA_fnc_serverEvent;
  > ["OCAP_setFocusStart", [120]] call CBA_fnc_serverEvent;

Public:
  No

Author:
  Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {};

params [["_frameNumber", GVAR(captureFrameNo), [0]]];

[":MISSION:FOCUS_START:", [_frameNumber]] call EFUNC(extension,sendData);
