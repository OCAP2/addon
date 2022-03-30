/* ----------------------------------------------------------------------------
Script: FUNC(exportData)

Description:
  This function facilitates the actual endMission and save events in the extension, prompting it to pack the mission and upload it to the web component.

  This function MUST be called in order to save a mission recording. A boolean true in the correct option of userconfig.hpp will automatically execute this function when the "MPEnded" Event Handler triggers.

Parameters:
  _side - The winning side [optional, Side]
  _message - A custom description of how the victory was achieved [optional, String]
  _tag - A custom tag to override that which is defined in userconfig.hpp that will make it filterable in web [optional, String]

Returns:
  Nothing

Examples:
  --- Code
  // "Mission ended"
  [] call FUNC(exportData);

  // "BLUFOR Win."
  [west] call FUNC(exportData);

  // "OPFOR Win. OPFOR controlled all sectors!
  [east, "OPFOR controlled all sectors!"] call FUNC(exportData);

  // "Independent Win. INDFOR stole the intel!"
  // Mission is saved under filterable "SnatchAndGrab" tag on web
  [independent, "INDFOR stole the intel!", "SnatchAndGrab"] call FUNC(exportData);
  ---

Public:
  Yes

Author:
  Dell, Zealot, IndigoFox, TyroneMF
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_side", "_message", "_tag", ["_overrideLimits", false, [false]]];
// overrideLimits will bypass any restriction checks, in case someone wants to save a mission even if doesn't meet their usual criteria


if (isNil QGVAR(startTime)) exitWith {
  // if recording hasn't started, there's nothing to save
  LOG(["Export data call received, but recording of this session hasn't yet started."]);

  {
    [{!isNull player}, {
      player createDiaryRecord [
        "OCAP2Info",
        [
          "Status",
          "<font color='#33FF33'>OCAP2 was asked to save, but recording hasn't started yet.</font>"
        ], taskNull, "", false
      ];
      player setDiarySubjectPicture [
        "OCAP2Info",
        "\A3\ui_f\data\igui\cfg\simpleTasks\types\use_ca.paa"
      ];
    }] call CBA_fnc_waitUntilAndExecute;
  } remoteExecCall ["call", 0, true];
};


_elapsedTime = time - GVAR(startTime);
_frameTimeDuration = (GVAR(frameCaptureDelay) * GVAR(captureFrameNo)) * 60;
TRACE_7("Save attempted. Elapsed Time =", _elapsedTime," Frame Count * Delay Duration =", _frameTimeDuration," delta =", _elapsedTime - _frameTimeDuration);


if (_frameTimeDuration < GVAR(minMissionTime) && !_overrideLimits) exitWith {
  // if the total duration in minutes is not met based on how many frames have been recorded & the frame capture delay,
  // then we won't save, but will continue recording in case admins want to save once that threshold is met.
  // allow this restriction to be overriden
  LOG("Save attempted, but the minimum recording duration hasn't been met. Not saving, continuing to record.");
  {
    player createDiaryRecord [
      "OCAP2Info",
      [
        "Status",
        (
          "<font color='#FFFF33'>OCAP2 capture of " + briefingName + " has not yet reached the minimum duration to save it. Recording will continue.</font>"
        )
      ]
    ];
    player setDiarySubjectPicture [
      "OCAP2Info",
      "\A3\ui_f\data\igui\cfg\simpleTasks\types\danger_ca.paa"
    ];
  } remoteExec ["call", 0, false];
};


call FUNC(stopRecording);
private _endFrameNumber = GVAR(captureFrameNo);

if (!isNil QGVAR(PFHObject)) then {
  [GVAR(PFHObject)] call CBA_fnc_deletePerFrameHandlerObject;
  GVAR(PFHObject) = nil;
};

// reset vars in case a new recording is started
GVAR(captureFrameNo) = 0;
GVAR(startTime) = nil;
{
  _x setVariable [QGVARMAIN(isInitialized), nil];
  _x setVariable [QGVARMAIN(exclude), nil];
  _x setVariable [QGVARMAIN(id), nil];
  _x setVariable [QGVARMAIN(unitType), nil];
} count (allUnits + allDeadMen + vehicles);
GVAR(nextId) = 0;


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


if (!isNil "_tag") then {
  [":SAVE:", [worldName, GVAR(missionName), getMissionConfigValue ["author", ""], GVAR(frameCaptureDelay), _endFrameNumber, _tag]] call EFUNC(extension,sendData);
  OCAPEXTLOG(ARR4("Saved recording of mission", GVAR(missionName), "with tag", _tag));
} else {// default tag to configured setting
  [":SAVE:", [worldName, GVAR(missionName), getMissionConfigValue ["author", ""], GVAR(frameCaptureDelay), _endFrameNumber, EGVAR(settings,saveTag)]] call EFUNC(extension,sendData);
  OCAPEXTLOG(ARR3("Saved recording of mission", GVAR(missionName), "with default tag"));
};

// briefingName is used here, no need for publicVariable for a simple confirmation log.
{
  player createDiaryRecord [
    "OCAP2Info",
    [
      "Status",
      (
        "<font color='#33FF33'>OCAP2 capture of " + briefingName + " has been exported with " + str(GVAR(endFrameNumber)) + " frames saved.</font>" +
        "<br/><br/>" +
        "Upload results have been logged."
      )
    ]
  ];
  player setDiarySubjectPicture [
    "OCAP2Info",
    "\A3\ui_f\data\igui\cfg\simpleTasks\types\upload_ca.paa"
  ];
} remoteExec ["call", 0, false];
