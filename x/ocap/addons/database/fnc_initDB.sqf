#include "script_component.hpp"

// Initialize DB
GVAR(dbValid) = false;


// when the extension is ready, it'll send a callback which will set dbValid to true and let the other functions being sending data
addMissionEventHandler ["ExtensionCallback", {
  if (_name != "ocap_recorder") exitWith {};

  params ["_name", "_function", "_data"];

  TRACE_3("ExtensionCallback", _name, _function, _data);

  if (_function isEqualTo ":VERSION:") exitWith {
    private _dataArr = parseSimpleArray _data;
    EGVAR(database,version) = _data#0;
    publicVariable QEGVAR(database,version);
    INFO_1("Version", EGVAR(database,version));
  };

  if (_function isEqualTo ":DB:ERROR:") exitWith {
    diag_log formatText ["OCAP: DB error: %1", _data];
    ERROR_MSG_1("Database connection error", _data);
  };


  if (_function isEqualTo ":DB:OK:") exitWith {
    _dataArr = parseSimpleArray _data;
    INFO_1("Database connection success", _data#0);
    if ((_data#0) isEqualTo "SQLITE") then {
      WARNING("SQLITE is used as a local fallback due to Postgres connection error -- the 'migratebackups' command will need to be used to centralize your data!");
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
      ["ocapRecorderExtensionVersion", EGVAR(database,version)]
    ]] call CBA_fnc_encodeJSON;

    // Save mission and world to DB
    INFO("Saving mission and world to DB");
    TRACE_2("World and mission context", GVAR(worldContext), GVAR(missionContext));
    [":NEW:MISSION:", [GVAR(worldContext), GVAR(missionContext)], 'ocap_recorder'] call FUNC(sendData);
  };

  if (_function isEqualTo ":MISSION:OK:") exitWith {
    INFO_1("Initialization completed in %1ms", diag_tickTime - GVAR(initTimer));
    INFO("Mission saved to DB, starting data send");
    GVAR(dbValid) = true;

    // set initial stuff unique to DB
    [] spawn FUNC(getStaticObjects);
    call FUNC(addEventHandlers);
    call FUNC(startLoop);
    removeMissionEventHandler ["ExtensionCallback", _thisEventHandler];
  };
}];




INFO("Initializing DB");
GVAR(initTimer) = diag_tickTime;
[":INIT:DB:", []] call FUNC(sendData);
true
