/* Run on the server in a disposable multiplayer mission; see tests/README.md. */
params ["_client", "_curator"];
if (!isServer || {!canSuspend}) exitWith {throw "Run the tests with server-side execVM"};
if (owner _client isEqualTo owner _curator) exitWith {throw "Two different player owners are required"};
if (!isNull getAssignedCuratorLogic _client || {isNull getAssignedCuratorLogic _curator}) exitWith {
  throw "Pass a non-curator client and an assigned curator";
};
if (missionNamespace getVariable ["OCAP_recorder_recording", false]) exitWith {throw "Disable auto-start and stop recording first"};

private _assert = {
  params ["_condition", "_description"];
  if (!_condition) then {throw _description};
  diag_log format ["[OCAP regression] PASS: %1", _description];
};
private _savedFunctions = createHashMap;
{
  _savedFunctions set [_x, missionNamespace getVariable _x];
} forEach [
  "CBA_fnc_addPerFrameHandler", "CBA_fnc_waitUntilAndExecute",
  "OCAP_extension_fnc_sendData", "OCAP_recorder_fnc_stopRecording",
  "OCAP_recorder_fnc_captureLoop", "OCAP_recorder_fnc_updateTime"
];
private _vehicle = objNull;
private _gun = objNull;
private _newGun = objNull;
private _authGun = objNull;
private _serverAi = objNull;
private _aiGroup = grpNull;
private _samplerGroup = grpNull;
private _samplerUnits = [];
private _error = "";
private _savedTime = CBA_missionTime;

// Intercept extension output, never upload a test recording. Execute the actual
// production PFH callbacks explicitly so sample timing is deterministic.
OCAP_test_commands = [];
OCAP_extension_fnc_sendData = {
  params ["_command", ["_args", []]];
  // Ignore unrelated telemetry and lifecycle events from the running mission.
  if (_command in [":PLAYER:MEDICAL:", ":PLAYER:INVENTORY:"] || {
    _command isEqualTo ":EVENT:GENERAL:" && {(_args param [1, ""]) in [
      "zeusEntity", "zeusCamera", "zeusPing", "zeusModule", "serviceEvent", "staticWeapon"
    ]}
  }) then {OCAP_test_commands pushBack +_this};
  ""
};
CBA_fnc_addPerFrameHandler = {OCAP_test_pfh = _this select 0; -1};
if (!isNil "OCAP_recorder_servicingPFH") then {
  [OCAP_recorder_servicingPFH] call CBA_fnc_removePerFrameHandler;
};
OCAP_recorder_servicingPFH = nil;
OCAP_settings_trackServicing = true;
OCAP_settings_trackConstructions = true;
OCAP_settings_trackZeus = true;
OCAP_settings_trackZeusPings = true;
OCAP_settings_trackZeusModules = true;
OCAP_settings_trackPlayerSnapshotDiffs = true;
// A listen host shares the server namespace. Keep its real periodic sampler
// quiet during endpoint tests; the client subtest enables inventory explicitly.
OCAP_settings_trackPlayerInventory = false;
OCAP_settings_trackPlayerInventoryOnDeath = false;
OCAP_settings_trackPlayerMedical = false;
OCAP_settings_trackPlayerStamina = false;
OCAP_settings_trackPlayerRadio = false;
OCAP_recorder_recording = true;
OCAP_recorder_startTime = 1;
OCAP_recorder_captureFrameNo = 100;
OCAP_recorder_nextId = 10;
OCAP_extension_sessionReady = true;
OCAP_isDebug = false;

try {
  call OCAP_recorder_fnc_trackServicing;
  private _sample = OCAP_test_pfh;
  OCAP_recorder_constructionsInitialized = nil;
  call OCAP_recorder_fnc_trackConstructions;
  private _sweep = OCAP_test_pfh;
  CBA_fnc_addPerFrameHandler = _savedFunctions get "CBA_fnc_addPerFrameHandler";

  // Real remoteExec calls: a client spoofs another player's object, including
  // an actual curator. A following message from that same sender is the barrier.
  _client setVariable ["OCAP_id", 0];
  _curator setVariable ["OCAP_id", 1];
  OCAP_recorder_playerSnapshotState = createHashMap;
  ["medical", _curator, createHashMapFromArray [["test", "original"]]] call OCAP_recorder_fnc_submitPlayerSnapshot;
  private _before = str OCAP_recorder_playerSnapshotState;
  OCAP_recorder_zeusByUid = createHashMap;
  OCAP_recorder_zeusLastCamera = createHashMap;
  OCAP_recorder_zeusPingLast = createHashMap;
  OCAP_recorder_staticDisassembleClaims = [];
  OCAP_recorder_staticWeaponSeen = createHashMap;
  _authGun = createVehicle ["B_HMG_01_F", [140, 140, 0], [], 0, "NONE"];
  _authGun setVariable ["OCAP_id", 25];
  OCAP_test_commands = [];
  OCAP_test_done = false;
  [[_client, _curator, _authGun], {
    params ["_client", "_curator", "_gun"];
    ["medical", _curator, createHashMapFromArray [["test", "forged"]]] remoteExecCall ["OCAP_recorder_fnc_submitPlayerSnapshot", 2];
    // Both impersonating a curator and claiming curator powers for oneself fail.
    {
      [_x, createHashMapFromArray [["x", 100], ["y", 200]]] remoteExecCall ["OCAP_recorder_fnc_submitZeusCamera", 2];
      [_x, _curator] remoteExecCall ["OCAP_recorder_fnc_submitZeusPing", 2];
      [_x, objNull, createHashMapFromArray [
        ["className", "Module_F"], ["displayName", "Test"], ["x", 100], ["y", 200]
      ]] remoteExecCall ["OCAP_recorder_fnc_submitZeusModule", 2];
    } forEach [_curator, _client];
    ["assembled", _curator, _gun] remoteExecCall ["OCAP_recorder_fnc_submitStaticWeapon", 2];
    ["disassembled", _curator, objNull] remoteExecCall ["OCAP_recorder_fnc_submitStaticWeapon", 2];
    {OCAP_test_done = true} remoteExecCall ["call", 2];
  }] remoteExecCall ["call", owner _client];
  private _deadline = diag_tickTime + 15;
  waitUntil {sleep 0.05; OCAP_test_done || {diag_tickTime > _deadline}};
  [OCAP_test_done, "spoofing client completed its requests"] call _assert;
  [str OCAP_recorder_playerSnapshotState isEqualTo _before, "spoof cannot replace another player's diff baseline"] call _assert;
  [OCAP_test_commands isEqualTo [], "spoofed snapshots, Zeus and static submissions emit nothing"] call _assert;
  [count OCAP_recorder_staticWeaponSeen == 0 && {OCAP_recorder_staticDisassembleClaims isEqualTo []}, "static spoofing leaves no assembly dedupe entry or disassembly claim"] call _assert;
  [count OCAP_recorder_zeusByUid == 0 && {count OCAP_recorder_zeusLastCamera == 0} && {count OCAP_recorder_zeusPingLast == 0}, "rejected Zeus submissions leave no entity or dedupe state"] call _assert;

  // Positive controls use the same remote endpoint and original client code path.
  OCAP_test_done = false;
  [_client, {
    ["medical", _this, createHashMapFromArray [["test", "own"]]] remoteExecCall ["OCAP_recorder_fnc_submitPlayerSnapshot", 2];
    {OCAP_test_done = true} remoteExecCall ["call", 2];
  }] remoteExecCall ["call", owner _client];
  _deadline = diag_tickTime + 15;
  waitUntil {sleep 0.05; OCAP_test_done || {diag_tickTime > _deadline}};
  [OCAP_test_done && {"0:medical" in OCAP_recorder_playerSnapshotState}, "owner can submit their own snapshot (including a listen host)"] call _assert;
  OCAP_test_done = false;
  [_curator, {
    [_this, createHashMapFromArray [["x", 100], ["y", 200]]] remoteExecCall ["OCAP_recorder_fnc_submitZeusCamera", 2];
    [_this, _this] remoteExecCall ["OCAP_recorder_fnc_submitZeusPing", 2];
    [_this, objNull, createHashMapFromArray [
      ["className", "Module_F"], ["displayName", "Test"], ["x", 100], ["y", 200]
    ]] remoteExecCall ["OCAP_recorder_fnc_submitZeusModule", 2];
    {OCAP_test_done = true} remoteExecCall ["call", 2];
  }] remoteExecCall ["call", owner _curator];
  _deadline = diag_tickTime + 15;
  waitUntil {sleep 0.05; OCAP_test_done || {diag_tickTime > _deadline}};
  [OCAP_test_done && {count OCAP_recorder_zeusLastCamera == 1}, "assigned curator can submit their own camera"] call _assert;
  [count OCAP_recorder_zeusPingLast == 1 && {count (OCAP_test_commands select {
    (_x select 0) isEqualTo ":EVENT:GENERAL:" && {((_x select 1) select 1) in ["zeusCamera", "zeusPing", "zeusModule"]}
  }) == 3}, "assigned curator can submit all three Zeus report types"] call _assert;

  OCAP_test_commands = [];
  OCAP_test_done = false;
  [[_client, _authGun], {
    params ["_unit", "_gun"];
    ["assembled", _unit, _gun] remoteExecCall ["OCAP_recorder_fnc_submitStaticWeapon", 2];
    ["disassembled", _unit, objNull] remoteExecCall ["OCAP_recorder_fnc_submitStaticWeapon", 2];
    {OCAP_test_done = true} remoteExecCall ["call", 2];
  }] remoteExecCall ["call", owner _client];
  _deadline = diag_tickTime + 15;
  waitUntil {sleep 0.05; (OCAP_test_done && {count OCAP_test_commands == 1}) || {diag_tickTime > _deadline}};
  [OCAP_test_done && {count OCAP_test_commands == 1} && {count OCAP_recorder_staticDisassembleClaims == 1}, "legitimate remote owner can submit static assembly and disassembly"] call _assert;
  [(OCAP_recorder_staticDisassembleClaims select 0 select 0) == 0, "remote owner's disassembly claim retains their unit id"] call _assert;
  OCAP_recorder_staticDisassembleClaims = [];
  OCAP_recorder_staticWeaponSeen = createHashMap;
  OCAP_test_commands = [];
  _aiGroup = createGroup [west, true];
  _serverAi = _aiGroup createUnit ["B_Soldier_F", [130, 130, 0], [], 0, "NONE"];
  _serverAi setVariable ["OCAP_id", 26];
  [local _serverAi, "positive control AI is server-local"] call _assert;
  ["assembled", _serverAi, _authGun] call OCAP_recorder_fnc_submitStaticWeapon;
  ["disassembled", _serverAi, objNull] call OCAP_recorder_fnc_submitStaticWeapon;
  _deadline = diag_tickTime + 15;
  waitUntil {sleep 0.05; count OCAP_test_commands == 1 || {diag_tickTime > _deadline}};
  [count OCAP_test_commands == 1 && {count OCAP_recorder_staticDisassembleClaims == 1}, "direct server AI calls can submit static assembly and disassembly"] call _assert;
  [(OCAP_recorder_staticDisassembleClaims select 0 select 0) == 26, "direct server claim retains the AI unit id"] call _assert;

  // Replace the client's controlled unit with an identical-kit unit, then change
  // only its server-issued id. The client runs the actual installed sampler.
  _samplerGroup = createGroup [west, true];
  {
    private _unit = _samplerGroup createUnit ["B_Soldier_F", [110 + _x, 110, 0], [], 0, "NONE"];
    _unit setVariable ["OCAP_id", _x, true];
    _unit disableAI "ALL";
    _samplerUnits pushBack _unit;
  } forEach [30, 31];
  _samplerGroup setGroupOwner (owner _client);
  OCAP_test_commands = [];
  OCAP_test_done = false;
  OCAP_test_samplerError = "";
  [[_samplerUnits select 0, _samplerUnits select 1, OCAP_recorder_startTime],
    compile preprocessFileLineNumbers "tests\client_sampler_regressions.sqf"
  ] remoteExecCall ["call", owner _client];
  _deadline = diag_tickTime + 30;
  waitUntil {sleep 0.05; OCAP_test_done || {diag_tickTime > _deadline}};
  [OCAP_test_done, "client unit-replacement regression finished"] call _assert;
  [OCAP_test_samplerError isEqualTo "", format ["client sampler checks: %1", OCAP_test_samplerError]] call _assert;
  private _inventories = OCAP_test_commands select {(_x select 0) isEqualTo ":PLAYER:INVENTORY:"};
  [count _inventories == 3, "server accepts one initial inventory per new id and drops the duplicate"] call _assert;
  {
    private _key = format ["%1:inventory", _x];
    private _state = OCAP_recorder_playerSnapshotState getOrDefault [_key, []];
    [_state isNotEqualTo [] && {(_state select 2) == 0} && {((_state select 1) get "unitId") == _x}, format ["entity %1 has a full initial inventory", _x]] call _assert;
  } forEach [30, 31, 32];
  [{((_x select 1 select 2) find """diffOf""") == -1} count _inventories == 3, "new-id inventory events contain full payloads"] call _assert;

  _vehicle = createVehicle ["B_Quadbike_01_F", [100, 100, 0], [], 0, "NONE"];
  _vehicle setVariable ["OCAP_id", 20];
  _vehicle enableSimulationGlobal false;
  // Keep this block unscheduled: the real CBA clock and surviving construction
  // PFH cannot interleave with these synthetic sample times.
  isNil {
    _vehicle setFuel 0.5;
    _vehicle setDamage 0.5;
    CBA_missionTime = 0;
    call _sample;
    OCAP_test_commands = [];
    for "_i" from 1 to 100 do {
      _vehicle setFuel (0.5 + _i * 0.005);
      _vehicle setDamage (0.5 - _i * 0.005);
      CBA_missionTime = _i;
      call _sample;
    };
    [count OCAP_recorder_serviceSessions == 2, "sub-threshold steps keep refuel and repair sessions open"] call _assert;
    [OCAP_test_commands isEqualTo [], "ongoing slow servicing emits no partial jobs"] call _assert;
    private _refuel = OCAP_recorder_serviceSessions get "20:refuel";
    private _repair = OCAP_recorder_serviceSessions get "20:repair";
    [abs ((_refuel select 6) - 0.5) < 0.0001 && {abs ((_refuel select 7) - 1) < 0.0001}, "slow refuel retains the whole half-tank span"] call _assert;
    [abs ((_repair select 6) - 0.5) < 0.0001 && {abs (_repair select 7) < 0.0001}, "slow repair retains the whole damage span"] call _assert;
    CBA_missionTime = 109;
    call _sample;
    [count OCAP_test_commands == 2 && {count OCAP_recorder_serviceSessions == 0}, "idle timeout emits one event per completed job"] call _assert;
    OCAP_test_commands = [];
    _vehicle setFuel 0.5;
    call _sample;
    _vehicle setFuel 0.505;
    CBA_missionTime = 110;
    call _sample;
    call OCAP_recorder_flushServiceSessions;
    [OCAP_test_commands isEqualTo [], "a whole job below the noise threshold is dropped"] call _assert;
    _vehicle setFuel 0.75;
    call _sample;
    call OCAP_recorder_flushServiceSessions;
    [count OCAP_test_commands == 1, "a normal single-step refuel still records"] call _assert;
    OCAP_test_commands = [];
    _vehicle setFuel 0.755;
    call _sample;
    _vehicle setFuel 0.5;
    call _sample;
    _vehicle setFuel 0.505;
    call _sample;
    call OCAP_recorder_flushServiceSessions;
    [OCAP_test_commands isEqualTo [], "a reversed session cannot record a negative refuel"] call _assert;
    CBA_missionTime = _savedTime;
  };

  // Queue an assembly in the first recording without letting CBA execute it.
  CBA_fnc_waitUntilAndExecute = {OCAP_test_wait = +_this};
  _gun = createVehicle ["B_HMG_01_F", [150, 150, 0], [], 0, "NONE"];
  ["assembled", _client, _gun] call OCAP_recorder_fnc_submitStaticWeapon;
  CBA_fnc_waitUntilAndExecute = _savedFunctions get "CBA_fnc_waitUntilAndExecute";
  _gun setVariable ["OCAP_id", 21];
  call _sweep;
  [21 in OCAP_recorder_staticWeaponSnapshot, "first recording tracks its static weapon"] call _assert;
  ["disassembled", _client, objNull] call OCAP_recorder_fnc_submitStaticWeapon;
  OCAP_recorder_serviceRearmSeen set ["20:mag:[]", CBA_missionTime];
  OCAP_recorder_fnc_stopRecording = {
    call OCAP_recorder_flushServiceSessions;
    OCAP_recorder_recording = false;
  };
  [sideUnknown, "Regression", "Regression", true] call OCAP_recorder_fnc_exportData;
  {
    [count (missionNamespace getVariable _x) == 0, format ["export clears %1", _x]] call _assert;
  } forEach [
    "OCAP_recorder_serviceBaseline", "OCAP_recorder_serviceSessions", "OCAP_recorder_serviceRearmSeen",
    "OCAP_recorder_staticWeaponSnapshot", "OCAP_recorder_staticDisassembleClaims", "OCAP_recorder_staticWeaponSeen",
    "OCAP_recorder_zeusPingLast"
  ];

  // Start through the real entry point, stubbing only the capture loop/time IO.
  OCAP_recorder_fnc_captureLoop = {OCAP_recorder_startTime = 2};
  OCAP_recorder_fnc_updateTime = {};
  OCAP_extension_sessionReady = true;
  call OCAP_recorder_fnc_startRecording;
  // Changed membership and ordering: a new gun takes the old vehicle id, while
  // the old vehicle takes the old gun id with very different fuel/damage values.
  deleteVehicle _gun;
  _newGun = createVehicle ["B_GMG_01_F", [180, 180, 0], [], 0, "NONE"];
  _newGun setVariable ["OCAP_id", 20];
  _vehicle setVariable ["OCAP_id", 21];
  _vehicle setFuel 1;
  _vehicle setDamage 0;
  OCAP_test_commands = [];
  call _sample;
  call _sweep;
  call OCAP_recorder_flushServiceSessions;
  // Exercise both the success and timeout paths of the old queued callback.
  (OCAP_test_wait select 2) call (OCAP_test_wait select 1);
  (OCAP_test_wait select 2) call (OCAP_test_wait select 4);
  [OCAP_test_commands isEqualTo [], "export then start with reused ids emits no fictitious servicing, disassembly or queued assembly"] call _assert;

  // Marker type exclusion (OCAP2/OCAP#99): a marker of an excluded type is
  // never recorded; a marker of another type still is. The type list is read
  // at event time, so assigning it directly is enough.
  OCAP_recorder_excludeMarkerTypeList = ["Empty"];
  OCAP_test_marker_commands = [];
  private _origMarkerSend = OCAP_extension_fnc_sendData;
  OCAP_extension_fnc_sendData = {
    params ["_command", ["_args", []]];
    private _result = call _origMarkerSend;
    if (_command in [":MARKER:CREATE:", ":MARKER:DELETE:"]) then {
      OCAP_test_marker_commands pushBack +_this;
    };
    _result
  };
  createMarker ["Empty", [500, 500, 0], "mk_type_excluded"];
  createMarker ["mil_dot", [510, 510, 0], "mk_type_kept"];
  // Marker creations are forwarded after a two second delay.
  private _markerDeadline = diag_tickTime + 15;
  waitUntil {
    sleep 0.1;
    ({"mk_type_kept" in str _x} count OCAP_test_marker_commands) > 0 || {diag_tickTime > _markerDeadline};
  };
  [({"mk_type_kept" in str _x} count OCAP_test_marker_commands) == 1, "marker of a non-excluded type is recorded"] call _assert;
  [({"mk_type_excluded" in str _x} count OCAP_test_marker_commands) == 0, "marker of an excluded type is not recorded"] call _assert;
  [("mk_type_kept" in OCAP_recorder_trackedMarkers) && {!("mk_type_excluded" in OCAP_recorder_trackedMarkers)}, "tracked marker list reflects the type exclusion"] call _assert;
  // Deletions carry no type information; the server drops deletions of markers
  // it never tracked, so both deletions are accepted as no-ops where needed.
  deleteMarker "mk_type_kept";
  deleteMarker "mk_type_excluded";
  _markerDeadline = diag_tickTime + 5;
  waitUntil {
    sleep 0.05;
    ({"mk_type_kept" in str _x} count OCAP_test_marker_commands) > 1 || {diag_tickTime > _markerDeadline};
  };
  [({"mk_type_kept" in str _x} count OCAP_test_marker_commands) == 2, "deletion of a tracked marker is recorded"] call _assert;
  [!("mk_type_excluded" in OCAP_recorder_trackedMarkers), "deleted excluded marker stays untracked"] call _assert;
  OCAP_extension_fnc_sendData = _origMarkerSend;
  OCAP_recorder_excludeMarkerTypeList = [];
  OCAP_test_marker_commands = [];
} catch {
  _error = _exception;
};

OCAP_recorder_recording = false;
CBA_missionTime = _savedTime;
{missionNamespace setVariable [_x, _y]} forEach _savedFunctions;
{if (!isNull _x) then {deleteVehicle _x}} forEach ([_vehicle, _gun, _newGun, _authGun, _serverAi] + _samplerUnits);
{if (!isNull _x) then {deleteGroup _x}} forEach [_aiGroup, _samplerGroup];
if (_error isNotEqualTo "") then {
  diag_log format ["[OCAP regression] FAIL: %1", _error];
  throw _error;
};
diag_log "[OCAP regression] ALL TESTS PASSED";
