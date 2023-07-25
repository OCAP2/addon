#include "script_component.hpp"

// Initialize DB
GVAR(dbValid) = false;


// when the extension is ready, it'll send a callback which will set dbValid to true and let the other functions being sending data
addMissionEventHandler ["ExtensionCallback", {
  params ["_name", "_function", "_data"];
  if (_name != "ocap_recorder") exitWith {};
  if (_function isEqualTo ":DB:OK:") exitWith {
    diag_log formatText ["OCAP: Initialized DB"];
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
      ["addons", _addons]
    ]] call CBA_fnc_encodeJSON;

    // Save mission and world to DB
    diag_log formatText ["OCAP: Saving mission and world to DB"];
    diag_log formatText ["%1", GVAR(worldContext)];
    diag_log formatText ["%1", GVAR(missionContext)];
    [":NEW:MISSION:", [GVAR(worldContext), GVAR(missionContext)], 'ocap_recorder'] call FUNC(sendData);
    };

    if (_function isEqualTo ":MISSION:OK:") exitWith {
      diag_log formatText ["OCAP: Saved mission and world to DB, proceeding with recording"];
      GVAR(dbValid) = true;

      // set initial stuff unique to DB
      [] spawn FUNC(getStaticObjects);
      call FUNC(addEventHandlers);
      call FUNC(startLoop);
      removeMissionEventHandler ["ExtensionCallback", _thisEventHandler];
    };
}];




diag_log formatText ["OCAP: Initializing DB"];
[":INIT:DB:", []] call FUNC(sendData);
true
