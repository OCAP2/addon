/*
  FILE: fnc_handleCustomEvent.sqf

  FUNCTION: OCAP_recorder_fnc_handleCustomEvent

  Description:
    Sends custom event data to the extension to save it to the timeline. This custom event data is later read by Javascript in the web component to determine how it should be displayed.

    Applied during initialization of OCAP in <OCAP_recorder_fnc_init>.

  Parameters:
    _type - classifier for the type of event. used to determine text & icon [[String], one of: "flag", "generalEvent"]
    _unit - name of the unit that performed the action [String]
    _unitColor - (optional) color for the unit's name shown in Events list and for the pulse on the map [[String], Hex RGB, defaults "" and will show as white]
    _objectiveColor - (optional) color representing the icon in Events list [[String], Hex RGB, defaults "" and will show as white]
    _position - (optional) the location to pulse on the map [<PositionATL>, default nil]

  Returns:
    Nothing

  Examples:
    (start code)
    ["ocap_handleCustomEvent", ["eventType", "eventMessage"]] call CBA_fnc_serverEvent;

    // saves a general event to the timeline
    ["ocap_handleCustomEvent", ["generalEvent", "eventText"]] call CBA_fnc_serverEvent;

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
    (end code)

  Public:
    Yes

  Author:
    Fank, Zealot
*/
#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {};

params ["_eventName", "_eventMessage"];
[":EVENT:",
  [GVAR(captureFrameNo), _eventName, _eventMessage]
] call EFUNC(extension,sendData);
