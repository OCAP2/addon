/* Sent as code by recorder_regressions.sqf; clients do not load OCAP functions. */
_this spawn {
  params ["_first", "_second", "_startTime"];
  private _originalPlayer = player;
  private _tick = {};
  private _removedPFH = false;
  private _error = "";
  private _assert = {
    params ["_condition", "_description"];
    if (!_condition) then {throw _description};
    diag_log format ["[OCAP regression client] PASS: %1", _description];
  };
  private _names = [
    "OCAP_recorder_recording", "OCAP_recorder_startTime",
    "OCAP_settings_trackPlayerInventory", "OCAP_settings_trackPlayerInventoryOnDeath",
    "OCAP_settings_trackPlayerMedical", "OCAP_settings_trackPlayerStamina", "OCAP_settings_trackPlayerRadio",
    "OCAP_settings_playerInventoryInterval", "OCAP_recorder_client_capturePlayerState",
    "OCAP_recorder_client_playerTrackingLast", "OCAP_recorder_client_playerTrackingFingerprint",
    "OCAP_recorder_client_playerTrackingSession", "OCAP_recorder_client_playerTrackingUnit",
    "OCAP_recorder_client_playerTrackingUnitId", "OCAP_recorder_client_playerTrackingSlot",
    "OCAP_recorder_client_radioSeen", "TFAR_radioCodesDisabled",
    "TFAR_fnc_activeLrRadio", "TFAR_fnc_getLrRadioCode", "TFAR_fnc_getLrRadioProperty"
  ];
  private _saved = createHashMap;
  {_saved set [_x, missionNamespace getVariable _x]} forEach _names;

  try {
    [!isNil "OCAP_recorder_client_playerTrackingPFH", "server bootstrap installed the client sampler"] call _assert;
    // Read the actual callback registered by the addon. This layout comes from
    // CBA common/fnc_addPerFrameHandler.sqf, for a non-zero interval handler.
    private _index = CBA_common_PFHhandles select OCAP_recorder_client_playerTrackingPFH;
    [_index >= 0, "sampler is a timed CBA handler"] call _assert;
    _tick = (CBA_common_perFrameHandlerArray select _index) select 0;
    [OCAP_recorder_client_playerTrackingPFH] call CBA_fnc_removePerFrameHandler;
    _removedPFH = true;

    OCAP_recorder_recording = true;
    OCAP_recorder_startTime = _startTime;
    OCAP_settings_trackPlayerInventory = true;
    OCAP_settings_trackPlayerInventoryOnDeath = false;
    OCAP_settings_playerInventoryInterval = 120;
    OCAP_settings_trackPlayerMedical = false;
    OCAP_settings_trackPlayerStamina = false;
    OCAP_settings_trackPlayerRadio = false;
    OCAP_test_client_captures = [];
    OCAP_test_client_captureOriginal = OCAP_recorder_client_capturePlayerState;
    OCAP_recorder_client_capturePlayerState = {
      OCAP_test_client_captures pushBack (player getVariable ["OCAP_id", -1]);
      _this call OCAP_test_client_captureOriginal;
    };

    private _deadline = diag_tickTime + 10;
    waitUntil {sleep 0.05; (local _first && {local _second} && {
      (_first getVariable ["OCAP_id", -1]) == 30 && {(_second getVariable ["OCAP_id", -1]) == 31}
    }) || {diag_tickTime > _deadline}};
    [local _first && {local _second} && {(_first getVariable ["OCAP_id", -1]) == 30} && {
      (_second getVariable ["OCAP_id", -1]) == 31
    }, "replacement units and their server ids reached the client"] call _assert;
    private _began = CBA_missionTime;
    private _id = _second getVariable ["OCAP_id", -1];
    isNil {
      selectPlayer _first;
      OCAP_recorder_client_playerTrackingSlot = 0;
      for "_i" from 1 to 4 do {call _tick};
      [OCAP_test_client_captures isEqualTo [30], "first unit receives one initial inventory"] call _assert;
      for "_i" from 1 to 4 do {call _tick};
      [OCAP_test_client_captures isEqualTo [30], "unchanged unit does not resend before its interval"] call _assert;
      private _fingerprint = [player] call OCAP_recorder_client_inventoryFingerprint;
      // Populate every old-unit cache, including radio readiness, to verify that
      // the replacement invalidates all kinds rather than just inventory.
      {
        OCAP_recorder_client_playerTrackingLast set [_x, CBA_missionTime];
        if (_x isNotEqualTo "inventory") then {
          OCAP_recorder_client_playerTrackingFingerprint set [_x, ["old unit"]];
        };
      } forEach ["inventory", "medical", "stamina", "radio"];
      OCAP_recorder_client_radioSeen = true;
      selectPlayer _second;
      [_fingerprint isEqualTo ([player] call OCAP_recorder_client_inventoryFingerprint), "replacement has an identical inventory fingerprint"] call _assert;
      for "_i" from 1 to 4 do {call _tick};
      [OCAP_test_client_captures isEqualTo [30, 31], "identical kit on a new player unit sends an initial inventory"] call _assert;
      {
        [(OCAP_recorder_client_playerTrackingLast get _x) == -1e10 && {
          !(_x in OCAP_recorder_client_playerTrackingFingerprint)
        }, format ["unit replacement resets %1 caches", _x]] call _assert;
      } forEach ["medical", "stamina", "radio"];
      [!OCAP_recorder_client_radioSeen, "unit replacement clears radio-seen state"] call _assert;

      // Isolate the object check: timestamps, id and session match, but the
      // cached object is from the old life. The next inventory turn is due.
      OCAP_recorder_client_playerTrackingUnit = _first;
      for "_i" from 1 to 4 do {call _tick};
      [OCAP_test_client_captures isEqualTo [30, 31, 31], "player-object changes invalidate caches independently of id changes"] call _assert;
    };

    // Change only the server-issued entity id on the same controlled object.
    [[_second, _id + 1], {
      params ["_unit", "_id"];
      _unit setVariable ["OCAP_id", _id, true];
    }] remoteExecCall ["call", 2];
    _deadline = diag_tickTime + 10;
    waitUntil {sleep 0.05; (_second getVariable ["OCAP_id", -1]) == _id + 1 || {diag_tickTime > _deadline}};
    [(_second getVariable ["OCAP_id", -1]) == 32, "new server entity id reached the client"] call _assert;
    isNil {
      for "_i" from 1 to 4 do {call _tick};
      [OCAP_test_client_captures isEqualTo [30, 31, 31, 32], "same player object with a new entity id receives initial inventory"] call _assert;
      [CBA_missionTime - _began < 120, "all replacements occurred before the old inventory interval elapsed"] call _assert;

      // Exercise the installed LR helper with an active-radio tuple. These mocks
      // enforce TFAR's different API contracts; no TFAR mod is needed in the mission.
      OCAP_test_lrRadioObject = _first;
      _first setVariable ["tf_encryptionCode", "OCAP_test_lrSideCode"];
      OCAP_test_lrSideCode = "regression-LR-code";
      TFAR_radioCodesDisabled = false;
      TFAR_fnc_activeLrRadio = {[OCAP_test_lrRadioObject, "radio_settings"]};
      TFAR_fnc_getLrRadioCode = {OCAP_test_lrCodeArgument = +_this; ""};
      TFAR_fnc_getLrRadioProperty = {
        params ["_radio", "_property", ["_default", ""]];
        if !(_radio isEqualType objNull) then {throw "LR property API received a tuple instead of an object"};
        OCAP_test_lrPropertyArguments = +_this;
        _radio getVariable [_property, _default]
      };
      private _lr = call TFAR_fnc_activeLrRadio;
      private _code = [_lr, "LR"] call OCAP_recorder_client_getTfarCode;
      [_code isEqualTo "regression-LR-code", "empty live LR code recovers its configured side code"] call _assert;
      [OCAP_test_lrCodeArgument isEqualTo _lr, "live LR code API receives the complete active-radio tuple"] call _assert;
      [OCAP_test_lrPropertyArguments isEqualTo [_first, "tf_encryptionCode", ""], "LR property API receives the radio object and property"] call _assert;
      OCAP_test_lrSideCode = "";
      [([_lr, "LR"] call OCAP_recorder_client_getTfarCode) isEqualTo "", "empty configured side code is accepted without a type error"] call _assert;
      TFAR_fnc_getLrRadioCode = {OCAP_test_lrCodeArgument = +_this; "live-LR-code"};
      OCAP_test_lrPropertyArguments = nil;
      [([_lr, "LR"] call OCAP_recorder_client_getTfarCode) isEqualTo "live-LR-code" && {
        isNil "OCAP_test_lrPropertyArguments"
      }, "non-empty live LR code bypasses the property fallback"] call _assert;
      TFAR_radioCodesDisabled = true;
      OCAP_test_lrCodeArgument = nil;
      [([_lr, "LR"] call OCAP_recorder_client_getTfarCode) isEqualTo "" && {
        isNil "OCAP_test_lrCodeArgument" && {isNil "OCAP_test_lrPropertyArguments"}
      }, "globally disabled codes bypass both LR APIs"] call _assert;
    };
  } catch {
    _error = _exception;
  };

  selectPlayer _originalPlayer;
  {missionNamespace setVariable [_x, _saved get _x]} forEach _names;
  if (_removedPFH) then {
    OCAP_recorder_client_playerTrackingPFH = [_tick, 1.25] call CBA_fnc_addPerFrameHandler;
  };
  [_error, {OCAP_test_samplerError = _this; OCAP_test_done = true}] remoteExecCall ["call", 2];
};
