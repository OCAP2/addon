#include "script_component.hpp"

if (!GVAR(enabled)) exitWith {
  INFO("Module disabled, exiting.");
  true
};

INFO("Module enabled. Starting up...");

// Initialize DB
GVAR(dbValid) = false;


// when the extension is ready, it'll send a callback which will set dbValid to true and let the other functions being sending data
addMissionEventHandler ["ExtensionCallback", {
  if (_name != "ocap_recorder") exitWith {};

  params ["_name", "_function", "_dataArr"];

  private _data = parseSimpleArray _dataArr;

  TRACE_3("ExtensionCallback", _name, _function, _data);

  if (_function isEqualTo ":VERSION:") exitWith {
    // version return is automatic during extension init process
    private _ver = _data#0;
    EGVAR(database,extensionVersion) = _ver;
    publicVariable QEGVAR(database,extensionVersion);
    INFO_1("Extension version: %1", str _ver);
  };

  if (_function isEqualTo ":GETDIR:ARMA:") exitWith {
    // arma dir return is automatic during extension init process
    private _dir = _data#0;
    GVAR(armaDir) = _dir;
    INFO_1("Arma directory: %1",_dir);
  };

  if (_function isEqualTo ":GETDIR:MODULE:") exitWith {
    // module dir return is automatic during extension init process
    private _dir = _data#0;
    GVAR(addonDir) = _dir;
    INFO_1("Addon directory: %1",_dir);
  };

  if (_function isEqualTo ":GETDIR:OCAPLOG:") exitWith {
    // logging dir return is automatic during extension init process
    private _dir = _data#0;
    GVAR(logPath) = _dir;
    INFO_1("Extension logging path: %1",_dir);
  };

  if (_function isEqualTo ":EXT:READY:") exitWith {
    INFO("Extension ready.");
    // extension is ready, send version
    [":ADDON:VERSION:", [QUOTE(VERSION_STR)], 'ocap_recorder'] call FUNC(sendData);

    // get arma dir and module dir
    [":GETDIR:ARMA:", nil, 'ocap_recorder'] call FUNC(sendData);
    [":GETDIR:MODULE:", nil, 'ocap_recorder'] call FUNC(sendData);

    // get logging dir
    [":GETDIR:OCAPLOG:", nil, 'ocap_recorder'] call FUNC(sendData);

    INFO("Connecting to services...");
    [":INIT:DB:", nil, 'ocap_recorder'] call FUNC(sendData);
  };


  if (_function isEqualTo ":DB:ERROR:") exitWith {
    private _error = _data#0;
    ERROR_MSG_1("Database connection error: %1",_error);
  };


  if (_function isEqualTo ":DB:OK:") exitWith {
    private _database = _data#0;
    INFO_1("Database connection success: %1",_database);
    if (toLower _database isEqualTo "sqlite") then {
      WARNING("SQLite is used as a local fallback due to Postgres connection error -- the 'migratebackups' command will need to be used to centralize your data!");
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
      ["extensionVersion", EGVAR(extension,version) # 0],
      ["extensionBuild", EGVAR(extension,version) # 1],
      ["ocapRecorderExtensionVersion", EGVAR(database,version)],
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

    // Save mission and world to DB
    INFO("Saving mission and world to DB");
    TRACE_2("World and mission context",GVAR(worldContext),GVAR(missionContext));
    [":NEW:MISSION:", [GVAR(worldContext), GVAR(missionContext)], 'ocap_recorder'] call FUNC(sendData);
  };

  if (_function isEqualTo ":MISSION:OK:") exitWith {
    INFO_1("Initialization completed in %1ms",diag_tickTime - GVAR(initTimer));
    INFO("Mission saved to DB. Starting data send.");
    GVAR(dbValid) = true;

    // set initial stuff unique to DB
    [] spawn FUNC(getStaticObjects);
    call FUNC(addEventHandlers);
    call FUNC(eh_fired_server);
    call FUNC(metricsLoop);
  };
}];


INFO("Initializing extension...");
GVAR(initTimer) = diag_tickTime;
[":INIT:", nil] call FUNC(sendData);
true
