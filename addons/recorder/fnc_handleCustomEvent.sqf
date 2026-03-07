/*
  FILE: fnc_handleCustomEvent.sqf

  FUNCTION: OCAP_recorder_fnc_handleCustomEvent

  Description:
    Routes custom events to the extension with typed positional args based on
    event type. Sector events (captured/contested/capturedFlag) use :EVENT:SECTOR:
    with structured fields; endMission uses :EVENT:ENDMISSION: with side and
    message; all other events use :EVENT:GENERAL: with JSON-encoded extraData.

    Applied during initialization of OCAP in <OCAP_recorder_fnc_init>.

  Parameters:
    _eventName    - event type classifier [String]
    _eventMessage - event payload [String or Array, depends on event type]
    _extraData    - (optional) additional data for generic events [HashMap or Array, default createHashMap]

  Returns:
    true

  Examples:
    (start code)
    // Sector captured with structured data (sent by fnc_trackSectors)
    [QGVARMAIN(customEvent), ["captured", ["sector", "Sector Alpha", [100, 200, 0]]]] call CBA_fnc_localEvent;

    // End mission with side and message
    [QGVARMAIN(customEvent), ["endMission", [str west, "BLUFOR controlled all sectors!"]]] call CBA_fnc_localEvent;

    // Generic event with optional extra data
    [QGVARMAIN(customEvent), ["generalEvent", "Some event text"]] call CBA_fnc_serverEvent;
    (end code)

  Public:
    Yes

  Author:
    Fank, Zealot
*/
#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {};

params [
  "_eventName",
  "_eventMessage",
  ["_extraData", createHashMap, [createHashMap, []]]
];

switch (_eventName) do {
  case "captured";
  case "contested";
  case "capturedFlag": {
    private _args = [GVAR(captureFrameNo), _eventName];

    if (_eventMessage isEqualType []) then {
      // Array format: ["objectType", "unitName", "side"?, "color"?, [posX, posY, posZ]?]
      _args pushBack (_eventMessage param [0, ""]);
      _args pushBack (_eventMessage param [1, ""]);
      // Extract side string if present at index 2
      private _maybeSide = _eventMessage param [2, ""];
      _args pushBack (if (_maybeSide isEqualType "") then {_maybeSide} else {""});
      {
        if (_x isEqualType [] && {count _x >= 2} && {(_x # 0) isEqualType 0}) exitWith {
          _args append _x;
        };
      } forEach _eventMessage;
    } else {
      // String format (legacy backward compat)
      _args pushBack _eventMessage;
    };

    [":EVENT:SECTOR:", _args] call EFUNC(extension,sendData);
  };

  case "endMission": {
    private _side = "";
    private _message = "";
    if (_eventMessage isEqualType []) then {
      _side = _eventMessage param [0, ""];
      _message = _eventMessage param [1, ""];
    } else {
      _message = _eventMessage;
    };
    [":EVENT:ENDMISSION:", [GVAR(captureFrameNo), _side, _message]] call EFUNC(extension,sendData);
  };

  default {
    [":EVENT:GENERAL:", [
      GVAR(captureFrameNo),
      _eventName,
      _eventMessage,
      [_extraData] call CBA_fnc_encodeJSON
    ]] call EFUNC(extension,sendData);
  };
};
true
