#include "script_component.hpp"

INFO("Module enabled. Starting up...");

// Initialize session
GVAR(sessionReady) = false;


// when the extension is ready, it'll send a callback which will set sessionReady to true and let the other functions being sending data
addMissionEventHandler ["ExtensionCallback", {
  params ["_name", "_function", "_dataArr"];

  if (_name != "ocap_recorder") exitWith {};

  private _data = parseSimpleArray _dataArr;

  TRACE_3("ExtensionCallback",_name,_function,_data);

  if (_function isEqualTo ":SYS:VERSION:") exitWith {
    // version return is automatic during extension init process
    private _ver = _data#0;
    GVAR(dllVersion) = _ver;
    publicVariable QGVAR(dllVersion);
    INFO_1("Extension version: %1",str _ver);
  };

  if (_function isEqualTo ":SYS:DIR:ARMA:") exitWith {
    // arma dir return is automatic during extension init process
    private _dir = _data#0;
    GVAR(armaDir) = _dir;
    INFO_1("Arma directory: %1",_dir);
  };

  if (_function isEqualTo ":SYS:DIR:MODULE:") exitWith {
    // module dir return is automatic during extension init process
    private _dir = _data#0;
    GVAR(addonDir) = _dir;
    INFO_1("Addon directory: %1",_dir);
  };

  if (_function isEqualTo ":SYS:DIR:LOG:") exitWith {
    // logging dir return is automatic during extension init process
    private _dir = _data#0;
    GVAR(logPath) = _dir;
    INFO_1("Extension logging path: %1",_dir);
  };

  if (_function isEqualTo ":SYS:READY:") exitWith {
    INFO("Extension ready.");
    // extension is ready, send version
    [":SYS:ADDON_VERSION:", [QUOTE(VERSION_STR)], 'ocap_recorder'] call FUNC(sendData);

    // get arma dir and module dir
    [":SYS:DIR:ARMA:", [], 'ocap_recorder'] call FUNC(sendData);
    [":SYS:DIR:MODULE:", [], 'ocap_recorder'] call FUNC(sendData);

    // get logging dir
    [":SYS:DIR:LOG:", [], 'ocap_recorder'] call FUNC(sendData);

    INFO("Initializing storage...");
    [":STORAGE:INIT:", [], 'ocap_recorder'] call FUNC(sendData);
  };


  if (_function isEqualTo ":STORAGE:ERROR:") exitWith {
    private _error = _data#0;
    ERROR_MSG_1("Storage initialization error: %1",_error);
  };


  if (_function isEqualTo ":STORAGE:OK:") exitWith {
    private _engine = _data#0;
    INFO_1("Storage initialized: %1",_engine);
    if (toLower _engine isEqualTo "sqlite") then {
      WARNING("SQLite is used as a local fallback due to Postgres connection error -- the 'migratebackups' command will need to be used to centralize your data!");
    };
    if (toLower _engine isEqualTo "memory") then {
      INFO("Memory-only mode active - data will be exported to JSON file");
    };

    // send mission data
    // Write mission and world to DB

    // WORLD
    _world = ( configfile >> "CfgWorlds" >> worldName );
    _author = getText( _world >> "author" );
    _name = getText ( _world >> "description" );
    _source = configSourceMod ( _world );
    _workshopID = '';
    {
      if ( ( _x#1 ) == _source ) then	{
        _workshopID = _x#7;
        break;
      };
    } foreach getLoadedModsInfo;

    GVAR(worldContext) = [createHashMapFromArray [
      ["author", _author],
      ["workshopID", _workshopID],
      ["displayName", _name],
      ["worldName", toLower worldName],
      ["worldNameOriginal", worldName],
      ["worldSize", getNumber(configFile >> "CfgWorlds" >> worldName >> "worldSize")],
      ["latitude", 1 - getNumber(configFile >> "CfgWorlds" >> worldName >> "latitude")],
      ["longitude", getNumber(configFile >> "CfgWorlds" >> worldName >> "longitude")]
    ]] call CBA_fnc_encodeJSON;

    // MISSION
    private _loadedMods = getLoadedModsInfo;
    private _addons = [];
    {
      _addons pushBack [_x#0, _x#7]; // name, workshop id
    } forEach _loadedMods;
    GVAR(missionContext) = [createHashMapFromArray [
      ["missionName", missionName],
      ["briefingName", briefingName],
      ["missionNameSource", missionNameSource],
      ["onLoadName", getMissionConfigValue ["onLoadName", ""]],
      ["author", getMissionConfigValue ["author", ""]],
      ["serverName", serverName],
      ["serverProfile", profileName],
      ["missionStart", nil],
      ["worldName", toLower worldName],
      ["tag", EGVAR(settings,saveTag)],
      ["captureDelay", EGVAR(settings,frameCaptureDelay)],
      ["addons", _addons],
      ["extensionBuildVersion", EGVAR(extension,version) # 0],
      ["extensionBuildCommit", EGVAR(extension,version) # 1],
      ["extensionBuildDate", EGVAR(extension,version) # 2],
      ["ocapRecorderExtensionVersion", GVAR(dllVersion)],
      ["playableSlots", [
          playableSlotsNumber east,
          playableSlotsNumber west,
          playableSlotsNumber independent,
          playableSlotsNumber civilian,
          playableSlotsNumber sideLogic
        ]
      ],
      ["sideFriendly", [
          [east, west] call BIS_fnc_sideIsFriendly,
          [east, independent] call BIS_fnc_sideIsFriendly,
          [west, independent] call BIS_fnc_sideIsFriendly
      ]]
    ]] call CBA_fnc_encodeJSON;

    // Save mission and world context
    INFO("Saving mission and world context");
    TRACE_2("World and mission context",GVAR(worldContext),GVAR(missionContext));
    [":MISSION:START:", [GVAR(worldContext), GVAR(missionContext)], 'ocap_recorder'] call FUNC(sendData);
  };

  if (_function isEqualTo ":MISSION:OK:") exitWith {
    INFO_1("Initialization completed in %1ms",diag_tickTime - GVAR(initTimer));
    INFO("Mission registered. Starting data send.");
    GVAR(sessionReady) = true;
  };

  if (_function isEqualTo ":MISSION:SAVED:") exitWith {
    // Payload shapes:
    //   ["ok", path]
    //   ["partial", path, error]
    //   ["error", error]
    // Type-check each field: if the extension ever sends something
    // unexpected, fall back to an empty string rather than crashing
    // the callback handler with a type error in the switch below.
    private _status = _data param [0, "", [""]];
    private _detail = _data param [1, "", [""]];
    private _extra  = _data param [2, "", [""]];

    // finalDiary appends a final status entry to the OCAPInfo diary
    // subject so the interim "being saved" record from fnc_exportData.sqf
    // is followed by the authoritative outcome.
    private _finalDiary = {
      params ["_diaryHtml"];
      [[_diaryHtml], {
        params ["_html"];
        player createDiaryRecord [
          "OCAPInfo",
          ["Status", _html]
        ];
      }] remoteExec ["call", [0, -2] select isDedicated, true];
    };

    switch (_status) do {
      case "ok": {
        INFO_1("Mission save complete — path: %1",_detail);
        GVAR(lastSaveResult) = ["ok", _detail];
        [
          format["OCAP saved %1 successfully", briefingName],
          2,
          [0, 0.8, 0, 1]
        ] remoteExec ["CBA_fnc_notify", [0, -2] select isDedicated];
        [format[
          "<font color='#33FF33'>OCAP capture of %1 has been exported and uploaded successfully.</font>",
          briefingName
        ]] call _finalDiary;
      };
      case "partial": {
        WARNING_2("Mission save complete but upload failed — path: %1 error: %2",_detail,_extra);
        GVAR(lastSaveResult) = ["partial", _detail, _extra];
        [
          format["OCAP saved locally (%1) but upload failed: %2", _detail, _extra],
          2,
          [1, 0.8, 0, 1]
        ] remoteExec ["CBA_fnc_notify", [0, -2] select isDedicated];
        [format[
          "<font color='#FFCC00'>OCAP capture of %1 was saved locally to %2, but the upload to the web server failed:</font><br/>%3",
          briefingName, _detail, _extra
        ]] call _finalDiary;
      };
      case "error": {
        ERROR_MSG_1("Mission save failed: %1",_detail);
        GVAR(lastSaveResult) = ["error", _detail];
        [
          format["OCAP save failed: %1", _detail],
          2,
          [1, 0, 0, 1]
        ] remoteExec ["CBA_fnc_notify", [0, -2] select isDedicated];
        [format[
          "<font color='#FF3333'>OCAP save of %1 failed:</font><br/>%2",
          briefingName, _detail
        ]] call _finalDiary;
      };
      default {
        WARNING_1("Unknown :MISSION:SAVED: status: %1",_status);
      };
    };
  };
}];


INFO("Initializing extension...");
GVAR(initTimer) = diag_tickTime;
[":SYS:INIT:", []] call FUNC(sendData);
true
