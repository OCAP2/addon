/* ----------------------------------------------------------------------------
FILE: fnc_exportData.sqf

FUNCTION: OCAP_recorder_fnc_exportData

Description:
  This function facilitates the actual endMission and save events in the extension, prompting it to pack the mission and upload it to the web component.

  Called directly, it is subject to the <OCAP_settings_minMissionTime> setting, and will not export if the mission is not long enough. It can also be called using <OCAP_listener_exportData> to bypass this check.

  When <OCAP_settings_saveMissionEnded> is true, this function will be called automatically when the mission ends.

  When <OCAP_settings_saveOnEmpty> is true, this function will execute when the last player leaves the mission (to lobby or when disconnecting).

  <OCAP_settings_saveTag> is used to tag the mission with a custom string, which can be used to identify the mission in the web component.

Parameters:
  _side - The winning side [optional, Side]
  _message - A custom description of how the victory was achieved [optional, String]
  _tag - A custom tag to override that which is defined in userconfig.hpp that will make it filterable in web [optional, String]

Returns:
  Nothing

Examples:
  (start code)
  // "Mission ended"
  [] call FUNC(exportData);

  // "BLUFOR Win."
  [west] call FUNC(exportData);

  // "OPFOR Win. OPFOR controlled all sectors!
  [east, "OPFOR controlled all sectors!"] call FUNC(exportData);

  // "Independent Win. INDFOR stole the intel!"
  // Mission is saved under filterable "SnatchAndGrab" tag on web
  [independent, "INDFOR stole the intel!", "SnatchAndGrab"] call FUNC(exportData);

  ["OCAP_exportData", west] call CBA_fnc_serverEvent;
  (end code)

Public:
  No

Author:
  Dell, Zealot, IndigoFox, TyroneMF
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_side", "_message", "_tag", ["_overrideLimits", false, [false]]];
// overrideLimits will bypass any restriction checks, in case someone wants to save a mission even if doesn't meet their usual criteria


if (isNil QGVAR(startTime)) exitWith {
  // if recording hasn't started, there's nothing to save
  LOG([localize LSTRING(RecordingNotStartedYet)]);

  [
    [
      localize LSTRING(Status),
      localize LSTRING(RecordingNotStartedYet)
    ],
    {
      [{!isNull player}, {
        player createDiaryRecord [
          "OCAPInfo",
          [
            _this select 0,
            format[
              "<font color='#33FF33'>%1</font>",
              _this select 1
            ]
          ], taskNull, "", false
        ];
        player setDiarySubjectPicture [
          "OCAPInfo",
          "\A3\ui_f\data\igui\cfg\simpleTasks\types\use_ca.paa"
        ];
      }, _this] call CBA_fnc_waitUntilAndExecute;
    }
   ] remoteExecCall ["call", 0, true];
};


_elapsedTime = time - GVAR(startTime);
_frameTimeDuration = (GVAR(frameCaptureDelay) * GVAR(captureFrameNo)) / 60;
TRACE_7("Save attempted. Elapsed Time =", _elapsedTime," Frame Count * Delay Duration =", _frameTimeDuration," delta =", _elapsedTime - _frameTimeDuration);


if (_frameTimeDuration < GVAR(minMissionTime) && !_overrideLimits) exitWith {
  // if the total duration in minutes is not met based on how many frames have been recorded & the frame capture delay,
  // then we won't save, but will continue recording in case admins want to save once that threshold is met.
  // allow this restriction to be overriden
  private _msg = format[localize LSTRING(MinimumDurationNotMet), GVAR(missionName)];
  LOG(_msg);
  [_msg, 1, [1, 1, 1, 1]] remoteExecCall ["CBA_fnc_notify", [0, -2] select isDedicated];
  [
    [
      localize LSTRING(Status),
      _msg
    ],
    {
      player createDiaryRecord [
        "OCAPInfo",
        [
          _this select 0,
          format[
            "<font color='#FFFF33'>%1</font>",
            _this select 1
          ]
        ]
      ];
      player setDiarySubjectPicture [
        "OCAPInfo",
        "\A3\ui_f\data\igui\cfg\simpleTasks\types\danger_ca.paa"
      ];
    }
  ] remoteExec ["call", 0, true];
};


call FUNC(stopRecording);
private _endFrameNumber = GVAR(captureFrameNo);

if (!isNil QGVAR(PFHObject)) then {
  [GVAR(PFHObject)] call CBA_fnc_deletePerFrameHandlerObject;
  GVAR(PFHObject) = nil;
};

if (isNil "_side") then {
  [":EVENT:", [_endFrameNumber, "endMission", ["", "Mission ended"]]] call EFUNC(extension,sendData);
};
if (isNil "_side" && !isNil "_message") then {
  [":EVENT:", [_endFrameNumber, "endMission", ["", _message]]] call EFUNC(extension,sendData);
};
if (!isNil "_side" && isNil "_message") then {
  [":EVENT:", [_endFrameNumber, "endMission", ["", _side]]] call EFUNC(extension,sendData);
};
if (!isNil "_side" && !isNil "_message") then {
  private _sideString = str(_side);
  if (_side == sideUnknown) then { _sideString = "" };
  [":EVENT:", [_endFrameNumber, "endMission", [_sideString, _message]]] call EFUNC(extension,sendData);
};

_msg = ""
if (!isNil "_tag") then {
  [":SAVE:", [worldName, GVAR(missionName), getMissionConfigValue ["author", ""], GVAR(frameCaptureDelay), _endFrameNumber, _tag]] call EFUNC(extension,sendData);
  _msg = format[
    localize LSTRING(SavedRecording),
    GVAR(missionName),
    _tag
  ];
  OCAPEXTLOG([_msg]);
} else {// default tag to configured setting
  [":SAVE:", [worldName, GVAR(missionName), getMissionConfigValue ["author", ""], GVAR(frameCaptureDelay), _endFrameNumber, EGVAR(settings,saveTag)]] call EFUNC(extension,sendData);
  _msg = format[
    localize LSTRING(SavedRecording),
    GVAR(missionName),
    "[default]"
  ];
  OCAPEXTLOG([_msg]);
};


// notify players that the recording was saved with a 2 second delay to ensure the "stopped recording" entries populate first
[_msg, 1, [1, 1, 1, 1]] remoteExec ["CBA_fnc_notify", [0, -2] select isDedicated];
[
  [
    GVAR(missionName),
    GVAR(captureFrameNo),
    localize LSTRING(Status),
    localize LSTRING(DiarySavedRecording1),
    localize LSTRING(DiarySavedRecording2)
  ], {
    params ["_missionName", "_endFrame"];

    player setDiarySubjectPicture [
      "OCAPInfo",
      "\A3\ui_f\data\igui\cfg\simpleTasks\types\upload_ca.paa"
    ];
    player createDiaryRecord [
      "OCAPInfo",
      [
        _this select 2,
        format[
          "<font color='#33FF33'>" + (_this select 3) + "</font><br/><br/>" + (_this select 4),
          _missionName,
          _endFrame
        ]
      ]
    ];
  }
] remoteExec ["call", [0, -2] select isDedicated, true];

// reset vars in case a new recording is started
GVAR(captureFrameNo) = 0;
publicVariable QGVAR(captureFrameNo);
GVAR(startTime) = nil;
{
  _x setVariable [QGVARMAIN(isInitialized), nil];
  _x setVariable [QGVARMAIN(exclude), nil];
  _x setVariable [QGVARMAIN(id), nil];
  _x setVariable [QGVARMAIN(unitType), nil];
} count (allUnits + allDeadMen + vehicles);
GVAR(nextId) = 0;
