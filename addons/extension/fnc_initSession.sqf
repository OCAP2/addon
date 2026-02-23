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
}];


INFO("Initializing extension...");
GVAR(initTimer) = diag_tickTime;
[":SYS:INIT:", []] call FUNC(sendData);
true
