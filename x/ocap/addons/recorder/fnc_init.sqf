/* ----------------------------------------------------------------------------
FILE: fnc_init.sqf

FUNCTION: OCAP_recorder_fnc_init

Description:
  Initializes event listeners, event handlers, gathers <OCAP_version> and <OCAP_extension_version>, and kicks off waiters for the auto-start conditions if settings are configured to enable it.

Parameters:
  None

Returns:
  Nothing

Example:
  > call OCAP_recorder_fnc_init

Public:
  No

Author:
  Dell, Zealot, IndigoFox
---------------------------------------------------------------------------- */

#include "script_component.hpp"

// exit if in 3DEN editor (when loaded in PreInit XEH)
if (is3DEN || !isMultiplayer) exitWith {};
// exit if not server
if (!isServer) exitWith {};
// if OCAP is disabled do nothing
if (!GVARMAIN(enabled)) exitWith {};
// if recording has already initialized this session then just start recording, don't re-init
if (!isNil QGVAR(startTime)) exitWith {
  if (!SHOULDSAVEEVENTS) exitWith {};
  call FUNC(startRecording)
};

// "debug_console" callExtension format["clientState: %1 (%2) | %3", getClientState, getClientStateNumber, __FILE__];

// VARIABLE: OCAP_recorder_recording
// Global variable that represents whether or not recording is active [Bool]
GVAR(recording) = false;
publicVariable QGVAR(recording);

/*
  VARIABLE: OCAP_recorder_captureFrameNo
  Global variable that represents the current frame number [Number]
*/
GVAR(captureFrameNo) = 0;
publicVariable QGVAR(captureFrameNo);

/*
  VARIABLE: OCAP_recorder_nextId
  Global variable that represents the next available id to assign to a unit or vehicle [Number]
*/
GVAR(nextId) = 0;



// save static setting values so changes during a mission don't interrupt timeline

/*
  VARIABLE: OCAP_recorder_frameCaptureDelay
  Global variable that represents the delay between frame captures in seconds. Gathered from CBA settings at init. [Number]
*/
GVAR(frameCaptureDelay) = EGVAR(settings,frameCaptureDelay);

/*
  VARIABLE: OCAP_recorder_autoStart
  Global variable that represents whether or not recording should automatically start. Gathered from CBA settings at init. [Bool]
*/
GVAR(autoStart) = EGVAR(settings,autoStart);


/*
  VARIABLE: OCAP_recorder_minMissionTime
  Global variable that represents the minimum mission time in seconds to qualify for saving. Can be overridden by using the <ocap_exportData> CBA event. Gathered from CBA settings at init. [Number]
*/
GVAR(minMissionTime) = EGVAR(settings,minMissionTime);

GVAR(projectileMonitorMultiplier) = 1;

/*
  VARIABLE: OCAP_version
  Global variable that represents the version of OCAP addon being used [String]
*/
GVARMAIN(version) = QUOTE(VERSION_STR);
publicVariable QGVARMAIN(version);

/*
  VARIABLE: OCAP_extension_version
  Global variable that represents the version of OCAP extension being used [String]
*/
EGVAR(extension,version) = ([":VERSION:", []] call EFUNC(extension,sendData));
publicVariable QEGVAR(extension,version);

// Add mission event handlers
call FUNC(addEventMission);

// remoteExec diary creation commands to clients listing version numbers and waiting start state
{
  [{!isNil QGVARMAIN(version) && !isNil QEGVAR(extension,version)}, {
    player createDiarySubject ["OCAPInfo", "OCAP AAR", "\A3\ui_f\data\igui\cfg\simpleTasks\types\whiteboard_ca.paa"];

    ocap_fnc_copyGitHubToClipboard = {copyToClipboard "https://github.com/OCAP2/OCAP"; systemChat "OCAP GitHub link copied to clipboard";};
    EGVAR(diary,about) = player createDiaryRecord [
      "OCAPInfo",
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
          "OCAP is a server-side Arma 3 recording suite that provides web-based playback of all units, vehicles, markers, and projectiles present, placed, and fired during a mission." +
          "<br/><br/>" +
          "Recording status can be found in the Status section." +
          "<br/><br/>" +
          "DISCLAIMER: This mission may be recorded and made publicly available at the discretion of the server administrators. Please be aware that your actions during this mission will be tracked and attributed to your in-game username."
        )
      ]
    ];

    EGVAR(diary,status) = player createDiaryRecord [
      "OCAPInfo",
      [
        "Status",
        "OCAP initialized."
      ]
    ];
  }] call CBA_fnc_waitUntilAndExecute;
} remoteExecCall ["call", [0, -2] select isDedicated, true];


// Support both methods of setting mission name.
GVAR(missionName) = getMissionConfigValue ["onLoadName", ""];
if (GVAR(missionName) == "") then {
    GVAR(missionName) = briefingName;
};


// On the dedicated server, the color of the markers is blue
// This overrides it with client data so it's saved properly
{
  _x params ["_name", "_color"];
  profilenamespace setVariable [_name, _color];
} forEach [
  ["map_blufor_r", 0],
  ["map_blufor_g", 0.3],
  ["map_blufor_b", 0.6],
  ["map_independent_r", 0],
  ["map_independent_g", 0.5],
  ["map_independent_b", 0],
  ["map_civilian_r", 0.4],
  ["map_civilian_g", 0],
  ["map_civilian_b", 0.5],
  ["map_unknown_r", 0.7],
  ["map_unknown_g", 0.6],
  ["map_unknown_b", 0],
  ["map_opfor_r", 0.5],
  ["map_opfor_g", 0],
  ["map_opfor_b", 0]
];


/*
  Conditional Start Recording
  We'll wait to see if auto-start is enabled and minPlayercount setting is met. This covers scenarios where someone changes the autostart setting during the mission as well, and excludes cases where autostart is disabled.
  If recording hasn't started already, we'll initialize it here assuming the above conditions are met.
  The startRecording function checks internally if recording has already started by other means via whether GVAR(startTime) has been declared or not.
  Start recording AFTER Briefing screen, so the beginning of the recording matches the start of the actual mission session.
*/
[
  {(getClientStateNumber > 9 && (count allPlayers) >= EGVAR(settings,minPlayerCount) && GVAR(autoStart)) || !isNil QGVAR(startTime)},
  {
    call FUNC(startRecording);
    [QGVARMAIN(customEvent), ["generalEvent", "Mission has started!"]] call CBA_fnc_serverEvent;
  }
] call CBA_fnc_waitUntilAndExecute;

// Auto-save on empty - checked every 30 seconds
// If a recording has been started, exceeds min mission time, and no players are on the server, auto-save
[{
  if (
    EGVAR(settings,saveOnEmpty) &&
    !isNil QGVAR(startTime) && (GVAR(frameCaptureDelay) * GVAR(captureFrameNo)) / 60 >= GVAR(minMissionTime) && count (call CBA_fnc_players) == 0
  ) then {
      [nil, "Recording ended due to server being empty"] call FUNC(exportData);
  };
}, 30] call CBA_fnc_addPerFrameHandler;

if (isNil QGVAR(projectileMonitorsInitialized)) then {
  call FUNC(projectileMonitors);
};

if (isNil QGVAR(entityMonitorsInitialized)) then {
  call FUNC(entityMonitors);
};
