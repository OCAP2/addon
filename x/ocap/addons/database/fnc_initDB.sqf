// Initialize DB
private _res = ["getDB", []] call FUNC(sendData);
_res params ["_code", "_result"];
if (_code == 1) exitWith {
  GVAR(dbValid) = false;
  textLogFormat ["OCAP: Failed to initialize DB"];
  textLogFormat ["OCAP: %1", _result];
};

GVAR(dbValid) = true;
textLogFormat ["OCAP: Initialized DB"];


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

GVAR(worldContext) = [[
  ["author", _author],
  ["workshopID", _workshopID],
  ["displayName", _name],
  ["worldName", toLower worldName],
  ["worldNameOriginal", worldName],
  ["worldSize", getNumber(configFile >> "CfgWorlds" >> worldName >> "worldSize")],
  ["latitude", getNumber(configFile >> "CfgWorlds" >> worldName >> "latitude")],
  ["longitude", getNumber(configFile >> "CfgWorlds" >> worldName >> "longitude")]
]] call CBA_fnc_encodeJSON;

// MISSION
GVAR(missionContext) = [[
  ["missionName", missionName],
  ["briefingName", briefingName],
  ["missionNameSource", missionNameSource],
  ["onLoadName", getMissionConfigValue ["onLoadName", ""]],
  ["author", getMissionConfigValue ["author", ""]],
  ["serverName", serverName],
  ["serverProfile", profileName],
  ["missionStart", "0"],
  ["worldName", toLower worldName],
  ["tag", EGVAR(settings,saveTag)]
]] call CBA_fnc_encodeJSON;

// Save mission and world to DB
private _res = ["logNewMission", [GVAR(worldContext), GVAR(missionContext)], 'ocap_recorder'] call FUNC(sendData);
_res params ["_code", "_result"];
if (_code == 1) exitWith {
  GVAR(dbValid) = false;
  textLogFormat ["OCAP: Failed to save mission and world to DB"];
  textLogFormat ["OCAP: %1", _result];
};
