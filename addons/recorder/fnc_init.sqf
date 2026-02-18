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

// Client-facing translations distributed to clients via publicVariable.
// Server-side only addon: clients don't have the stringtable, so we embed
// all translations here and look up by the client's `language` at runtime.
GVAR(translations) = createHashMap;
{
  _x params ["_key", "_en", "_de"];
  GVAR(translations) set [_key, createHashMapFromArray [["English", _en], ["German", _de]]];
} forEach [
  [LSTRING(About), "About", "Info"],
  [LSTRING(AlreadyRecording), "OCAP was asked to record and is already recording!", "OCAP wurde zum Aufnehmen aufgefordert und nimmt bereits auf!"],
  [LSTRING(CaptureFrame), "Capture frame:", "Aufnahme-Frame:"],
  [LSTRING(Controls), "Controls", "Steuerung"],
  [LSTRING(DiaryAdminControlsText), "These controls can be used to Start Recording, Pause Recording, and Save/Export the Recording. On the backend, these use the corresponding CBA server events that can be found in the documentation. Because of this, they override the default minimum duration required to save, so be aware that clicking ""Stop and Export Recording"" will save and upload your current recording regardless of its duration.", "Diese Steuerungen können zum Starten, Pausieren und Speichern/Exportieren der Aufnahme verwendet werden. Im Hintergrund verwenden sie die entsprechenden CBA-Server-Events aus der Dokumentation. Dadurch wird die standardmäßige Mindestdauer zum Speichern umgangen. Beachten Sie, dass ein Klick auf ""Aufnahme stoppen und exportieren"" Ihre aktuelle Aufnahme unabhängig von ihrer Dauer speichert und hochlädt."],
  [LSTRING(DiaryRecordingStarted), "OCAP started recording.", "OCAP hat die Aufnahme gestartet."],
  [LSTRING(DiarySavedRecording1), "OCAP capture of %1 has been exported with %2 frames saved.", "OCAP-Aufnahme von %1 wurde mit %2 gespeicherten Frames exportiert."],
  [LSTRING(DiarySavedRecording2), "Upload results have been logged.", "Upload-Ergebnisse wurden protokolliert."],
  [LSTRING(DiarySubjectTitle), "OCAP Admin", "OCAP Admin"],
  [LSTRING(Disclaimer), "DISCLAIMER: This mission may be recorded and made publicly available at the discretion of the server administrators. Please be aware that your actions during this mission will be tracked and attributed to your in-game username.", "HINWEIS: Diese Mission kann nach Ermessen der Serveradministratoren aufgezeichnet und öffentlich zugänglich gemacht werden. Bitte beachten Sie, dass Ihre Aktionen während dieser Mission verfolgt und Ihrem Spielernamen zugeordnet werden."],
  [LSTRING(InMissionTimeElapsed), "In-Mission Time Elapsed:", "Vergangene Missionszeit:"],
  [LSTRING(MinimumDurationNotMet), "OCAP capture of %1 has not yet reached the minimum duration to save it. Recording will continue.", "OCAP-Aufnahme von %1 hat die Mindestdauer zum Speichern noch nicht erreicht. Die Aufnahme wird fortgesetzt."],
  [LSTRING(MinimumDurationNotMetNotify), "OCAP attempted to save, but the minimum recording duration hasn't been met. Recording will continue.", "OCAP hat versucht zu speichern, aber die Mindestaufnahmedauer wurde nicht erreicht. Die Aufnahme wird fortgesetzt."],
  [LSTRING(MissionWorldTime), "Mission World Time:", "Missions-Weltzeit:"],
  [LSTRING(NotYetReceived), "not yet received", "noch nicht empfangen"],
  [LSTRING(OCAPInitialized), "OCAP initialized.", "OCAP initialisiert."],
  [LSTRING(OCAPSavedFrames), "OCAP saved %1 frames successfully", "OCAP hat %1 Frames erfolgreich gespeichert"],
  [LSTRING(PauseRecording), "Pause Recording", "Aufnahme pausieren"],
  [LSTRING(RecordingNotStartedYet), "OCAP was asked to save, but recording hasn't started yet.", "OCAP wurde zum Speichern aufgefordert, aber die Aufnahme hat noch nicht begonnen."],
  [LSTRING(RecordingPaused), "OCAP paused recording", "OCAP hat die Aufnahme pausiert"],
  [LSTRING(RecordingStarted), "OCAP began recording", "OCAP hat die Aufnahme begonnen"],
  [LSTRING(StartRecording), "Start/Resume Recording", "Aufnahme starten/fortsetzen"],
  [LSTRING(StartRecordingExtFailed), "OCAP failed to start recording: extension did not respond", "OCAP konnte die Aufnahme nicht starten: Extension hat nicht geantwortet"],
  [LSTRING(Status), "Status", "Status"],
  [LSTRING(StopRecording), "Stop and Export Recording", "Aufnahme stoppen und exportieren"],
  [LSTRING(SystemTimeUTC), "System Time UTC:", "Systemzeit UTC:"]
];
publicVariable QGVAR(translations);

// Lookup function: resolves on client using `language` command
GVAR(fnc_tr) = {
  private _map = GVAR(translations) getOrDefault [_this, createHashMap];
  _map getOrDefault [language, _map getOrDefault ["English", _this]]
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
            "Addon version: " + GVARMAIN(version) +
            "<br/>" +
            "Extension version: " + (EGVAR(extension,version) # 0) + " (" + (EGVAR(extension,version) # 1) + ", built " + (EGVAR(extension,version) # 2) + ")" +
            "<br/>" +
            "<execute expression='call ocap_fnc_copyGitHubToClipboard;'>https://github.com/OCAP2/OCAP</execute>" +
            "<br/><br/>" +
            "OCAP is a server-side Arma 3 recording suite that provides web-based playback of all units, vehicles, markers, and projectiles present, placed, and fired during a mission." +
            "<br/><br/>" +
            "Recording status can be found in the Status section." +
            "<br/><br/>" +
            LSTRING(Disclaimer) call GVAR(fnc_tr)
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
