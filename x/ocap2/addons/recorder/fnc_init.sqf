/* ----------------------------------------------------------------------------
Script: ocap_fnc_init

Description:
  Automatic Start: Called from ocap_fnc_autoStart.
  Manual Start: Server execution to begin.

Parameters:
  None

Returns:
  Nothing

Examples:
  --- Code
  call ocap_fnc_init;
  ---

Public:
  No

Author:
  Dell, Zealot, IndigoFox
---------------------------------------------------------------------------- */

#include "script_component.hpp"

// exit if in 3DEN editor (when loaded in PreInit XEH
if (is3DEN) exitWith {};
// if OCAP is disabled do nothing
if (!GVARMAIN(enabled)) exitWith {};
// if recording has already initialized this session then just start recording, don't re-init
if (!isNil QGVAR(startTime)) exitWith {call FUNC(startRecording)};

// bool: GVAR(recording)
GVAR(recording) = false;
publicVariable QGVAR(recording);
// int: GVAR(captureFrameNo)
GVAR(captureFrameNo) = 0;
publicVariable QGVAR(captureFrameNo);

// save static setting values so changes during a mission don't interrupt timeline
GVAR(frameCaptureDelay) = EGVAR(settings,frameCaptureDelay);
GVAR(autoStart) = EGVAR(settings,autoStart);
GVAR(minMissionTime) = EGVAR(settings,minMissionTime);

// macro: GVARMAIN(version)SION
GVARMAIN(version) = QUOTE(VERSION_STR);
publicVariable QGVARMAIN(version);

EGVAR(extension,version) = ([":VERSION:", []] call EFUNC(extension,sendData));
publicVariable QEGVAR(extension,version);


// remoteExec diary creation commands to clients listing version numbers and waiting start state
{
  [{!isNil QGVARMAIN(version) && !isNil QEGVAR(extension,version)}, {
    player createDiarySubject ["OCAP2Info", "OCAP2 AAR", "\A3\ui_f\data\igui\cfg\simpleTasks\types\whiteboard_ca.paa"];

    ocap_fnc_copyGitHubToClipboard = {copyToClipboard "https://github.com/OCAP2/OCAP"; systemChat "OCAP2 GitHub link copied to clipboard";};
    EGVAR(diary,about) = player createDiaryRecord [
      "OCAP2Info",
      [
        "About",
        (
          "<font size='20' face='PuristaBold'><font color='#BBBBBB'>OCAP</font><font color='#44AAFF'>2</font></font><br/>" +
          "Addon version: " + GVARMAIN(version) +
          "<br/>" +
          "Extension version: " + (EGVAR(extension,version) # 0) + " (built " + (EGVAR(extension,version) # 1) + ")" +
          "<br/>" +
          "<execute expression='call ocap_fnc_copyGitHubToClipboard;'>https://github.com/OCAP2/OCAP</execute>" +
          "<br/><br/>" +
          "OCAP2 is a server-side Arma 3 recording suite that provides web-based playback of all units, vehicles, markers, and projectiles present, placed, and fired during a mission." +
          "<br/><br/>" +
          "Recording status can be found in the Status section." +
          "<br/><br/>" +
          "DISCLAIMER: This mission may be recorded and made publicly available at the discretion of the server administrators. Please be aware that your actions during this mission will be tracked and attributed to your in-game username."
        )
      ]
    ];

    EGVAR(diary,status) = player createDiaryRecord [
      "OCAP2Info",
      [
        "Status",
        "OCAP2 initialized."
      ]
    ];
  }] call CBA_fnc_waitUntilAndExecute;
} remoteExecCall ["call", 0, true];


// Support both methods of setting mission name.
GVAR(missionName) = getMissionConfigValue ["onLoadName", ""];
if (GVAR(missionName) == "") then {
    GVAR(missionName) = briefingName;
};

/*
  Conditional Start Recording
  We'll wait to see if auto-start is enabled and minPlayercount setting is met. This covers scenarios where someone changes the autostart setting during the mission as well, and excludes cases where autostart is disabled.
  If recording hasn't started already, we'll initialize it here assuming the above conditions are met.
  The startRecording function checks internally if recording has already started by other means via whether GVAR(startTime) has been declared or not.
*/
[
  {((count allPlayers) >= EGVAR(settings,minPlayerCount) && GVAR(autoStart)) || !isNil QGVAR(startTime)},
  {call FUNC(startRecording)}
] call CBA_fnc_waitUntilAndExecute;

// When the server progresses past briefing and enters the mission, save an event to the timeline if recording
[{getClientStateNumber > 9}, {
  if (!SHOULDSAVEEVENTS) exitWith {};
  [QGVARMAIN(customEvent), ["generalEvent", "Mission has started!"]] call CBA_fnc_serverEvent;
}] call CBA_fnc_waitUntilAndExecute;



// PFH to track bullets
[{
  {
    if (isNull (_x#0)) then {
      _x params ["_obj", "_firerId", "_frame", "_pos"];
      [":FIRED:", [
        _firerId,
        _frame,
        _pos
      ]] call EFUNC(extension,sendData);

      if (GVARMAIN(isDebug)) then {
        OCAPEXTLOG(ARR4("FIRED EVENT: BULLET", _frame, _firerId, str _pos));
      };
      GVAR(liveBullets) = GVAR(liveBullets) - [_x];
    } else {
      _x set [3, getPosASL (_x#0)];
    };
  } forEach GVAR(liveBullets);
}] call CBA_fnc_addPerFrameHandler;

// PFH to track missiles, rockets, shells
[{
  {
    _x params ["_obj", "_magazine", "_firer", "_pos", "_markName"];
    if (isNull (_x#0)) then {

      _firer setVariable [
        QGVARMAIN(lastFired),
        getText(configFile >> "CfgMagazines" >> _magazine >> "displayName")
      ];

      if (GVARMAIN(isDebug)) then {
        OCAPEXTLOG(ARR4("FIRED EVENT: SHELL-ROCKET-MISSILE", _frame, _firerId, str _pos));
      };

      [{[QGVARMAIN(handleMarker), ["DELETED", _this]] call CBA_fnc_localEvent}, _markName, 10] call CBA_fnc_waitAndExecute;
      GVAR(liveMissiles) = GVAR(liveMissiles) - [_x];

    } else {
      _nowPos = getPosASL (_x#0);
      _x set [3, _nowPos];
      [QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, _nowPos, "", "", "", getDir (_x#0), "", "", 1]] call CBA_fnc_localEvent;
    };
  } forEach GVAR(liveMissiles);
}, GVAR(frameCaptureDelay) * 0.3] call CBA_fnc_addPerFrameHandler;

// PFH to track grenades, flares, thrown charges
[{
  {
    _x params ["_obj", "_magazine", "_firer", "_pos", "_markName", "_ammoSimType"];
    if (isNull (_x#0)) then {

      if !(_ammoSimType in ["shotSmokeX", "shotIlluminating"]) then {
        _firer setVariable [
          QGVARMAIN(lastFired),
          getText(configFile >> "CfgMagazines" >> _magazine >> "displayName")
        ];
      };

      if (GVARMAIN(isDebug)) then {
        OCAPEXTLOG(ARR4("FIRED EVENT: GRENADE-FLARE-SMOKE", _frame, _firerId, str _pos));
      };

      [{[QGVARMAIN(handleMarker), ["DELETED", _this]] call CBA_fnc_localEvent}, _markName, 10] call CBA_fnc_waitAndExecute;
      GVAR(liveGrenades) = GVAR(liveGrenades) - [_x];

    } else {
      _nowPos = getPosASL (_x#0);
      _x set [3, _nowPos];
      [QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, _nowPos, "", "", "", getDir (_x#0), "", "", 1]] call CBA_fnc_localEvent;
    };
  } forEach GVAR(liveGrenades);
}, GVAR(frameCaptureDelay)] call CBA_fnc_addPerFrameHandler;
