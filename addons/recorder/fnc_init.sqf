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
diag_log text "[OCAP] Fetching extension version...";
EGVAR(extension,version) = ([":VERSION:", []] call EFUNC(extension,sendData));
diag_log text format ["[OCAP] Extension version result: %1 (type: %2)", EGVAR(extension,version), typeName EGVAR(extension,version)];
publicVariable QEGVAR(extension,version);

/*
  VARIABLE: OCAP_recorder_restrictMarkersCompat
  Global variable flag to prevent a client's local markers from being recorded on the server, in the case of the mod Restrict Markers being loaded and enabled. Otherwise, marker recording would create lots of duplicates that hurt playback performance.
*/
GVAR(restrictMarkersCompat) = isClass (configFile >> "CfgPatches" >> "restrict_markers") && {missionNamespace getVariable ["restrict_markers_main_enabled", false]};
publicVariable QGVAR(restrictMarkersCompat);

// Client-facing translation fallback map distributed via publicVariable.
// Server-side only addon: clients don't have the stringtable. On the server,
// `localize` returns the English (Original) text. If a client installs an
// optional stringtable addon, `localize` returns their language directly.
// Otherwise the flat map provides the English fallback.
GVAR(tr) = createHashMapFromArray [
  [LSTRING(About), localize LSTRING(About)],
  [LSTRING(AboutAddonVersion), localize LSTRING(AboutAddonVersion)],
  [LSTRING(AboutExtVersion), localize LSTRING(AboutExtVersion)],
  [LSTRING(AboutOverview), localize LSTRING(AboutOverview)],
  [LSTRING(AboutStatusNote), localize LSTRING(AboutStatusNote)],
  [LSTRING(AlreadyRecording), localize LSTRING(AlreadyRecording)],
  [LSTRING(CaptureFrame), localize LSTRING(CaptureFrame)],
  [LSTRING(Controls), localize LSTRING(Controls)],
  [LSTRING(DiaryAdminControlsText), localize LSTRING(DiaryAdminControlsText)],
  [LSTRING(DiaryRecordingStarted), localize LSTRING(DiaryRecordingStarted)],
  [LSTRING(DiarySavedRecording1), localize LSTRING(DiarySavedRecording1)],
  [LSTRING(DiarySavedRecording2), localize LSTRING(DiarySavedRecording2)],
  [LSTRING(DiarySubjectTitle), localize LSTRING(DiarySubjectTitle)],
  [LSTRING(Disclaimer), localize LSTRING(Disclaimer)],
  [LSTRING(InMissionTimeElapsed), localize LSTRING(InMissionTimeElapsed)],
  [LSTRING(MinimumDurationNotMet), localize LSTRING(MinimumDurationNotMet)],
  [LSTRING(MinimumDurationNotMetNotify), localize LSTRING(MinimumDurationNotMetNotify)],
  [LSTRING(MissionWorldTime), localize LSTRING(MissionWorldTime)],
  [LSTRING(NotYetReceived), localize LSTRING(NotYetReceived)],
  [LSTRING(OCAPInitialized), localize LSTRING(OCAPInitialized)],
  [LSTRING(OCAPSavedFrames), localize LSTRING(OCAPSavedFrames)],
  [LSTRING(PauseRecording), localize LSTRING(PauseRecording)],
  [LSTRING(RecordingNotStartedYet), localize LSTRING(RecordingNotStartedYet)],
  [LSTRING(RecordingPaused), localize LSTRING(RecordingPaused)],
  [LSTRING(RecordingStarted), localize LSTRING(RecordingStarted)],
  [LSTRING(StartRecording), localize LSTRING(StartRecording)],
  [LSTRING(StartRecordingExtFailed), localize LSTRING(StartRecordingExtFailed)],
  [LSTRING(Status), localize LSTRING(Status)],
  [LSTRING(StopRecording), localize LSTRING(StopRecording)],
  [LSTRING(SystemTimeUTC), localize LSTRING(SystemTimeUTC)]
];
publicVariable QGVAR(tr);

// Lookup function: try client-side localize first (works if optional
// stringtable addon is installed), fall back to server-resolved English.
GVAR(fnc_tr) = {
  private _r = localize _this;
  if (_r == "") then { _r = GVAR(tr) getOrDefault [_this, _this] };
  _r
};
publicVariable QGVAR(fnc_tr);

// Add mission event handlers
call FUNC(addEventMission);

// Check already-connected players for admin controls (fixes race condition
// where players connected before OCAP initialized don't get diary entries)
// Wait for getUserInfo to be populated before calling, as it may not be ready during postInit
{
  private _pid = str owner _x;
  [{
    private _info = getUserInfo _this;
    !isNil "_info" && {_info isEqualType [] && {count _info >= 11}}
  }, {
    [_this, "connect"] call FUNC(adminUIcontrol);
  }, _pid, 30] call CBA_fnc_waitUntilAndExecute;
} forEach allPlayers;

// remoteExec diary creation commands to clients listing version numbers and waiting start state
[{
    [{!isNil QGVARMAIN(version) && !isNil QEGVAR(extension,version) && !isNil QGVAR(fnc_tr)}, {
      player createDiarySubject ["OCAPInfo", "OCAP AAR", "\A3\ui_f\data\igui\cfg\simpleTasks\types\whiteboard_ca.paa"];

      ocap_fnc_copyGitHubToClipboard = {copyToClipboard "https://github.com/OCAP2/OCAP"; systemChat "OCAP GitHub link copied to clipboard";};
      EGVAR(diary,about) = player createDiaryRecord [
        "OCAPInfo",
        [
          LSTRING(About) call GVAR(fnc_tr),
          (
            "<font size='20' face='PuristaBold'><font color='#BBBBBB'>OCAP</font><font color='#44AAFF'>2</font></font><br/>" +
            format[LSTRING(AboutAddonVersion) call GVAR(fnc_tr), GVARMAIN(version)] +
            "<br/>" +
            format[LSTRING(AboutExtVersion) call GVAR(fnc_tr), EGVAR(extension,version) # 0, EGVAR(extension,version) # 1, EGVAR(extension,version) # 2] +
            "<br/>" +
            "<execute expression='call ocap_fnc_copyGitHubToClipboard;'>https://github.com/OCAP2/OCAP</execute>" +
            "<br/><br/>" +
            (LSTRING(AboutOverview) call GVAR(fnc_tr)) +
            "<br/><br/>" +
            (LSTRING(AboutStatusNote) call GVAR(fnc_tr)) +
            "<br/><br/>" +
            (LSTRING(Disclaimer) call GVAR(fnc_tr))
          )
        ]
      ];

      EGVAR(diary,status) = player createDiaryRecord [
        "OCAPInfo",
        [
          LSTRING(Status) call GVAR(fnc_tr),
          LSTRING(OCAPInitialized) call GVAR(fnc_tr)
        ]
      ];
    }] call CBA_fnc_waitUntilAndExecute;
}] remoteExecCall ["call", [0, -2] select isDedicated, true];


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


// Initialize DB connection and log world/mission info
// Conditionals are housed in that module
EGVAR(database,dbValid) = false;
call EFUNC(database,initDB);

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

if (isNil QGVAR(entityMonitorsInitialized)) then {
  call FUNC(entityMonitors);
};
