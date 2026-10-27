/* Run on the server in a disposable multiplayer mission; see tests/README.md. */
if (!isServer || {!canSuspend}) exitWith {throw "Run the tests with server-side execVM"};
if (
  missionNamespace getVariable ["OCAP_recorder_recording", false] ||
  {!isNil "OCAP_recorder_startTime"} ||
  {missionNamespace getVariable ["OCAP_extension_sessionPending", false]}
) exitWith {throw "Disable auto-start, and run the tests before any recording started"};
if (isNil "OCAP_extension_missionContext") exitWith {throw "Wait for the extension storage to initialize first"};
// The stubs below replace addon functions, which CBA compiles final; otherwise
// real lifecycle commands would reach the extension.
if (isFinal OCAP_extension_fnc_sendData) exitWith {throw "Use a test build of the addon (DISABLE_COMPILE_CACHE); see tests/README.md"};

private _assert = {
  params ["_condition", "_description"];
  if (!_condition) then {throw _description};
  diag_log format ["[OCAP save limits] PASS: %1", _description];
};
private _savedFunctions = createHashMap;
{
  _savedFunctions set [_x, missionNamespace getVariable _x];
} forEach [
  "OCAP_extension_fnc_sendData",
  "OCAP_recorder_fnc_captureLoop", "OCAP_recorder_fnc_updateTime",
  "OCAP_recorder_fnc_announceRecording"
];
private _savedSettings = [
  OCAP_settings_saveMissionEnded, OCAP_recorder_minMissionTime, OCAP_recorder_frameCaptureDelay
];
private _error = "";

// Intercept the lifecycle commands, never register or upload a test recording.
OCAP_test_commands = [];
OCAP_test_startModes = [];
OCAP_extension_fnc_sendData = {
  params ["_command", "_args"];
  if (_command in [":MISSION:START:", ":MISSION:SAVE:", ":MISSION:DISCARD:", ":MISSION:KEEP:"]) then {
    OCAP_test_commands pushBack _command;
  };
  if (_command isEqualTo ":MISSION:START:") then {OCAP_test_startModes pushBack (_args param [3, ""])};
  ""
};
OCAP_recorder_fnc_captureLoop = {OCAP_recorder_startTime = time};
OCAP_recorder_fnc_updateTime = {};
// Its events are recorded only while the capture runs.
OCAP_test_announcedCapturing = [];
OCAP_recorder_fnc_announceRecording = {OCAP_test_announcedCapturing pushBack !isNil "OCAP_recorder_startTime"};
// A fresh recording waiting for the extension to register the mission.
private _registering = {
  OCAP_recorder_recording = false;
  OCAP_recorder_captureFrameNo = 0;
  OCAP_recorder_startTime = nil;
  OCAP_extension_sessionReady = false;
  OCAP_extension_sessionPending = false;
  OCAP_test_commands = [];
  OCAP_test_announcedCapturing = [];
  call OCAP_recorder_fnc_startRecording;
  sleep 1;
};
// What :MISSION:OK: does, in one frame like the callback handler.
private _confirm = {
  isNil {
    OCAP_extension_sessionPending = false;
    OCAP_extension_sessionReady = true;
  };
};
private _sent = {
  params ["_command"];
  {_x isEqualTo _command} count OCAP_test_commands
};
// A recording that has run for _minutes, as the capture loop leaves it.
private _recordingOf = {
  params ["_minutes"];
  OCAP_recorder_recording = true;
  OCAP_recorder_startTime = time;
  OCAP_recorder_captureFrameNo = round (_minutes * 60 / OCAP_recorder_frameCaptureDelay);
  OCAP_extension_sessionReady = true;
  OCAP_test_commands = [];
};

try {
  OCAP_settings_saveMissionEnded = true;
  OCAP_recorder_minMissionTime = 20;
  OCAP_recorder_frameCaptureDelay = 1;

  // The mission registers with the extension when recording starts, once,
  // however often a start is requested before the extension confirms it.
  call _registering;
  call OCAP_recorder_fnc_startRecording;
  sleep 1;
  [[":MISSION:START:"] call _sent == 1, "a start registers the mission once"] call _assert;
  [OCAP_test_startModes isEqualTo ["discard"] && {!OCAP_extension_recordingKept}, "a recording the game moves on from is dropped until it is long enough"] call _assert;
  [OCAP_extension_sessionPending, "the registration waits for :MISSION:OK:"] call _assert;
  [isNil "OCAP_recorder_startTime", "capture waits for the extension"] call _assert;
  [OCAP_test_announcedCapturing isEqualTo [], "nothing is announced before the capture runs"] call _assert;
  sleep 31;
  [OCAP_extension_sessionPending && {OCAP_recorder_recording}, "a slow extension is still waited for"] call _assert;
  call _confirm;
  sleep 1;
  [!isNil "OCAP_recorder_startTime", "capture begins once the extension confirms"] call _assert;
  [OCAP_test_announcedCapturing isEqualTo [true], "the start is announced once, while capturing"] call _assert;
  call OCAP_recorder_fnc_startRecording;
  [OCAP_test_announcedCapturing isEqualTo [true], "another start request does not start the capture again"] call _assert;

  // A mission the extension could not start stops the recording.
  call _registering;
  OCAP_extension_sessionPending = false; // what :MISSION:FAILED: does
  sleep 1;
  [isNil "OCAP_recorder_startTime" && {!OCAP_recorder_recording}, "a failed start ends the recording"] call _assert;
  [OCAP_test_announcedCapturing isEqualTo [], "a failed start is not announced"] call _assert;

  // A mission that ends while it registers is discarded once registered.
  call _registering;
  OCAP_recorder_missionEnded = true;
  call _confirm;
  sleep 1;
  OCAP_recorder_missionEnded = nil;
  [[":MISSION:DISCARD:"] call _sent == 1, "a mission that ended while registering is discarded"] call _assert;
  [isNil "OCAP_recorder_startTime" && {!OCAP_recorder_recording} && {!OCAP_extension_sessionReady}, "its capture never begins"] call _assert;

  // A pause while the mission registers holds the capture back until recording resumes.
  call _registering;
  call OCAP_recorder_fnc_stopRecording;
  call _confirm;
  sleep 1;
  [isNil "OCAP_recorder_startTime" && {OCAP_test_announcedCapturing isEqualTo []}, "a paused registration does not capture"] call _assert;
  call OCAP_recorder_fnc_startRecording;
  [!isNil "OCAP_recorder_startTime" && {OCAP_test_announcedCapturing isEqualTo [true]}, "resuming begins the capture"] call _assert;

  // A start request while it registers undoes a pause.
  call _registering;
  call OCAP_recorder_fnc_stopRecording;
  call OCAP_recorder_fnc_startRecording;
  [OCAP_recorder_recording && {[":MISSION:START:"] call _sent == 1}, "the latest request wins, still one registration"] call _assert;
  call _confirm;
  sleep 1;
  [!isNil "OCAP_recorder_startTime", "the capture begins once registered"] call _assert;

  // A start a minute after an unanswered registration registers again; the
  // first registration's late answers, even before the new start goes out,
  // change nothing (the real callback handler).
  waitUntil {sleep 1; diag_tickTime > 62}; // a negative send time reads as not sent
  call _registering;
  private _first = OCAP_extension_registrationToken;
  OCAP_extension_registrationSentAt = diag_tickTime - 61;
  isNil {
    call OCAP_recorder_fnc_startRecording; // registers again in a later frame
    ["ocap_recorder", ":MISSION:OK:", str ["OK", _first]] call OCAP_extension_fnc_handleCallback;
  };
  [OCAP_extension_sessionPending && {!OCAP_extension_sessionReady}, "a late OK of the given-up registration is ignored"] call _assert;
  sleep 1;
  [[":MISSION:START:"] call _sent == 2 && {OCAP_extension_registrationToken isNotEqualTo _first}, "the mission registers again with a new token"] call _assert;
  ["ocap_recorder", ":MISSION:FAILED:", str ["late", _first]] call OCAP_extension_fnc_handleCallback;
  sleep 1;
  [OCAP_extension_sessionPending && {OCAP_recorder_recording} && {isNil "OCAP_recorder_startTime"}, "nor is its late failure, and nothing captures yet"] call _assert;
  ["ocap_recorder", ":MISSION:OK:", str ["OK", OCAP_extension_registrationToken]] call OCAP_extension_fnc_handleCallback;
  sleep 1;
  [!isNil "OCAP_recorder_startTime" && {OCAP_test_announcedCapturing isEqualTo [true]}, "the new registration's OK begins the capture, announced once"] call _assert;

  // A registered mission paused before its capture is discarded at mission end.
  call _registering;
  call OCAP_recorder_fnc_stopRecording;
  call _confirm;
  sleep 1;
  call OCAP_recorder_fnc_handleMissionEnded;
  OCAP_recorder_missionEnded = nil;
  [[":MISSION:DISCARD:"] call _sent == 1 && {!OCAP_extension_sessionReady}, "a registered mission never captured is discarded"] call _assert;
  [OCAP_test_announcedCapturing isEqualTo [], "players are not told about it"] call _assert;

  // A mission that ends before the minimum is discarded, not saved.
  [5] call _recordingOf;
  call OCAP_recorder_fnc_handleMissionEnded;
  sleep 1;
  [[":MISSION:DISCARD:"] call _sent == 1, "a short recording is discarded when the mission ends"] call _assert;
  [[":MISSION:SAVE:"] call _sent == 0, "a short recording is not saved"] call _assert;
  [isNil "OCAP_recorder_startTime" && {!OCAP_extension_sessionReady}, "a discard resets the recording"] call _assert;

  // A mission script saving it on the same frame wins over the discard.
  [5] call _recordingOf;
  isNil {
    call OCAP_recorder_fnc_handleMissionEnded;
    [sideUnknown, "Regression", "Regression", true] call OCAP_recorder_fnc_exportData;
  };
  sleep 1;
  [[":MISSION:SAVE:"] call _sent == 1, "an explicit export of a short recording is saved"] call _assert;
  [[":MISSION:DISCARD:"] call _sent == 0, "a saved recording is not discarded"] call _assert;

  // A recording past the minimum is saved as before.
  [25] call _recordingOf;
  call OCAP_recorder_fnc_handleMissionEnded;
  sleep 1;
  [[":MISSION:SAVE:"] call _sent == 1, "a long recording is saved when the mission ends"] call _assert;
  [[":MISSION:DISCARD:"] call _sent == 0, "a long recording is not discarded"] call _assert;

  // Without auto-save on mission end, nothing happens.
  OCAP_settings_saveMissionEnded = false;
  [5] call _recordingOf;
  call OCAP_recorder_fnc_handleMissionEnded;
  sleep 1;
  [OCAP_test_commands isEqualTo [], "saveMissionEnded disabled neither saves nor discards"] call _assert;

  // A pause before anything started is held: auto-start leaves it alone
  // (OCAP_recorder_fnc_init), and the next start request lifts it.
  OCAP_recorder_missionEnded = nil; // set by the mission end checks above
  OCAP_recorder_recording = false;
  OCAP_recorder_startTime = nil;
  OCAP_extension_sessionReady = false;
  OCAP_extension_sessionPending = false;
  call OCAP_recorder_fnc_stopRecording;
  [OCAP_recorder_heldByPause, "a pause before the capture is held"] call _assert;
  call _registering;
  [!OCAP_recorder_heldByPause && {OCAP_extension_sessionPending}, "a start request lifts it and registers"] call _assert;
  call _confirm;
  sleep 1;

  // Discarding before a recording started does nothing.
  OCAP_recorder_startTime = nil;
  OCAP_extension_sessionReady = false;
  OCAP_test_commands = [];
  ["test"] call OCAP_recorder_fnc_discardRecording;
  [OCAP_test_commands isEqualTo [], "no recording, nothing to discard"] call _assert;
} catch {
  _error = _exception;
};

OCAP_recorder_recording = false;
OCAP_recorder_startTime = nil;
OCAP_recorder_missionEnded = nil;
OCAP_recorder_heldByPause = nil;
OCAP_recorder_captureFrameNo = 0;
OCAP_extension_sessionReady = false;
OCAP_extension_sessionPending = false;
_savedSettings params ["_saveMissionEnded", "_minMissionTime", "_frameCaptureDelay"];
OCAP_settings_saveMissionEnded = _saveMissionEnded;
OCAP_recorder_minMissionTime = _minMissionTime;
OCAP_recorder_frameCaptureDelay = _frameCaptureDelay;
{missionNamespace setVariable [_x, _y]} forEach _savedFunctions;

if (_error isEqualTo "") then {
  diag_log "[OCAP save limits] ALL TESTS PASSED";
} else {
  diag_log format ["[OCAP save limits] FAILED: %1", _error];
};
