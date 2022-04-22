/* ----------------------------------------------------------------------------
Script: FUNC(handleCustomEvent)

Description:
  Used for applying global event handlers.

  * Applied during initialization of OCAP2 in <ocap_fnc_init>.

Parameters:
  _type - objective type that will define the text & icon [String, one of: "flag"]
  _unit - name of the unit that performed the action [String]
  _unitColor - color for the unit's name shown in Events list and for the pulse on the map [String, Hex RGB, defaults "" and will show as white]
  _objectiveColor - color representing the icon in Events list [String, Hex RGB, defaults "" and will show as white]
  _position - the location to pulse on the map [optional, PositionATL, default nil]

Returns:
  Nothing

Examples:
  --- Code
  ["ocap_handleCustomEvent", ["eventType", "eventMessage"]] call CBA_fnc_serverEvent;

  // indicates a flag has been captured
  ["ocap_handleCustomEvent", ["captured", [
    "flag",
    name _unit,
    str side group _unit,
    "#FF0000",
    getPosAtl _flag
  ]]] call call CBA_fnc_serverEvent;


  // Not yet implemented
  ["ocap_handleCustomEvent", ["captured", [
    "sector",
    name _unit,
    str side group _unit,
    "#FF0000",
    getPosAtl _sectorObject
  ]]] call call CBA_fnc_serverEvent;
  ---

Public:
  Yes

Author:
  Fank, Zealot
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {};

params ["_eventName", "_eventMessage"];
[":EVENT:",
  [GVAR(captureFrameNo), _eventName, _eventMessage]
] call EFUNC(extension,sendData);
