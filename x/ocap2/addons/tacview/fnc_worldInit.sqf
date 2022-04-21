#include "script_component.hpp"

_centerLat = -1 * getNumber(configFile >> "CfgWorlds" >> worldName >> "latitude");
_centerLng = getNumber(configFile >> "CfgWorlds" >> worldName >> "longitude");
((date) apply {if (_x < 10) then {"0" + str _x} else {str _x}}) params ["_year", "_month", "_day", "_hours", "_minutes"];
(systemTime apply {if (_x < 10) then {"0" + str _x} else {str _x}}) params ["_sysyear", "_sysmonth", "_sysday", "_syshours", "_sysminutes", "_sysseconds"];
GVAR(filename) = format["%1-%2-%3T%4:%5:%6Z_%7",_sysyear, _sysmonth, _sysday, _syshours, _sysminutes, _sysseconds];
["FileType=text/acmi/tacview"] call FUNC(sendData);
["FileVersion=2.1"] call FUNC(sendData);
_missionDate = format["%1-%2-%3T%4:%5:00Z",_year, _month, _day, _hours, _minutes];
// _systemDate = format["RecordingTime=%1-%2-%3T%4:%5:%6Z",_sysyear, _sysmonth, _sysday, _syshours, _sysminutes, _sysseconds];
// format["0,%1,%2", _missionDate, _systemDate] call FUNC(sendData);
format["0,RecordingTime=%1,ReferenceTime=%2", __DATE_STR_ISO8601__, _missionDate] call FUNC(sendData);
format["0,DataSource=Arma 3 %1", QUOTE(__GAME_VER__)] call FUNC(sendData);
format["0,DataRecorder=OCAP2 v%1", QUOTE(GVARMAIN(version))] call FUNC(sendData);
format["0,Title=%1", GVAR(missionName)] call FUNC(sendData);
format["0,Category=%1", EGVAR(settings,saveTag)] call FUNC(sendData);
format["0,Author=%1", (getMissionConfigValue ["Author", ""])] call FUNC(sendData);
format["0,Briefing=%1", (getMissionConfigValue ["OverviewText", ""])] call FUNC(sendData);

GVAR(recordingData) = "";

GVAR(sideToCoalitionCache) = createHashMapFromArray [
  [blufor, "BLUFOR"],
  [opfor, "OPFOR"],
  [independent, "INDFOR"],
  [civilian, "CIV"]
];

GVAR(sideToColorCache) = createHashMapFromArray [
  [blufor, "Blue"],
  [opfor, "Red"],
  [independent, "Green"],
  [civilian, "Violet"]
];

// simulation of cfgammo, [tacviewType, hasExplosion]
GVAR(projectileTypeCache) = createHashMapFromArray [
  ["shotgrenade", ["Misc+Minor", 1]],
  ["shotrocket", ["Weapon+Rocket", 1]],
  ["shotmissile", ["Weapon+Missile", 1]],
  ["shotshell", ["Weapon+Projectile", 1]],
  ["shotmine", ["Misc+Minor", 1]],
  ["shotilluminating", ["Misc+Decoy+Flare", 0]],
  ["shotsmokex", ["Misc+Decoy+SmokeGrenade", 2]],
  ["shotcm", ["Misc+Decoy+Flare", 0]]
];





/*

mapGrid data from ACE Common + MicroDAGR



/*
* Author: VKing, bux
* Gets the current latitude and altitude offset for the map.
*
* Arguments:
* 0: Map name (default: worldName) <STRING>
*
* Return Value:
* 0: Latitude <NUMBER>
* 1: Altitude <NUMBER>
*
* Example:
* ["altis"] call ace_common_fnc_getMapData
*
* Public: No
*/

/*
* Author: PabstMirror
* Finds real x/y offset and map step for a 10 digit grid
* Save time by preparing data one time at startup
* Ideas from Nou's mapGridToPos and BIS_fnc_gridToPos
*
* Arguments:
* None
*
* Return Value:
* None
*
* Example:
* [] call ace_common_fnc_getMapGridData
* (populates var ace_common_mapGridData)
*
* Public: No
*/

/*
* Author: VKing, PabstMirror
* Gets a 10-digit map grid for the given world position
*
* Arguments:
* 0: Position (2D Position) <ARRAY>
* 1: Return type; false for array of easting and northing, true for single string (default: false) <BOOL>
*
* Return Value:
* 0: Easting <String>
* 1: Northing <String>
*
* Example:
* [getPos player] call ace_common_fnc_getMapGridFromPos
*
* Public: Yes
*/

/*
* Author: VKing
* Gets the current map's MGRS grid zone designator and 100km square.
* Also gets longitude, latitude and altitude offset for the map.
* Writes return values to GVAR(MGRS_data) if run on the current map.
*
* Arguments:
* 0: Map name (default: worldName) <STRING>
*
* Return Value:
* 0: Grid zone designator <STRING>
* 1: 100km square <STRING>
* 2: GZD + 100km sq. as a single string <STRING>
*
* Example:
* ["worldName"] call ace_common_fnc_getMGRSdata
*
* Public: No
*/

/*
* Author: PabstMirror
* Gets position from grid cords
*
* Arguments:
* 0: Grid Cords <STRING>
* 1: Grid center (true), Grid Bottom Right (false) (default: true) <BOOL>
*
* Return Value:
* Position <ARRAY>
*
* Example:
* ["6900080085"] call ace_common_fnc_getMapPosFromGrid
*
* Public: Yes
*/

// grid zone, 100km sq, longstring, saved to ace_common_MGRS_data
[worldName] call ace_common_fnc_getMGRSdata;

// GVAR(mapData) = [worldName] call ace_common_fnc_getMapData;
GVAR(altitudeOffset) = -1 * getNumber(configfile >> "CfgWorlds" >> worldName >> "outsideHeight");


GVAR(mapGrid) = getNumber(configFile >> "CfgWorlds" >> worldName >> "mapZone");
// mapGrid = (parseNumber(ace_common_MGRS_data # 0)) call BIS_fnc_numberDigits;
// mapGrid = parseNumber((mapGrid select {_x isEqualType 2}) joinString '');

// this is our starting grid, 0,0
// need to get 39 N 25 E as lower left
// GVAR(latitudeBase) = mapData select 0;
private _lat = getNumber(configfile >> "CfgWorlds" >> worldName >> "latitude");
private _lon = getNumber(configfile >> "CfgWorlds" >> worldName >> "longitude");
if (_lat == 0) then {
  GVAR(latitudeBase) = 39;
  GVAR(longitudeBase) = 26;
} else {
  GVAR(latitudeBase) = _lat;
  GVAR(longitudeBase) = _lon;
};

// now we find our coords in lnglat
_getOffset = [0, 0, GVAR(mapGrid) ] call FUNC(UTMtoDeg);

// add Latitude base -- longitude is taken care of by mapGrid param
_getOffset set [0, _getOffset # 0];
_getOffset set [1, _getOffset # 1 + GVAR(latitudeBase)];
// get the decimal positioning offset to make all coords based off of the bottom left corner of grid

GVAR(longitudeOffset) = ((_getOffset # 0) % floor(_getOffset # 0));
GVAR(latitudeOffset) = ((_getOffset # 1) % floor(_getOffset # 1));



GVAR(botLeftLngLat) = [[0,0]] call FUNC(getInitialLonLat);
GVAR(topRightLngLat) = [[worldSize, worldSize]] call FUNC(getInitialLonLat);
GVAR(lonMin) = GVAR(botLeftLngLat) select 0;
GVAR(latMin) = GVAR(botLeftLngLat) select 1;
GVAR(lonMax) = GVAR(topRightLngLat) select 0;
GVAR(latMax) = GVAR(topRightLngLat) select 1;

GVAR(latScale) = (GVAR(latMax) - GVAR(latMin)) / worldSize;
GVAR(lonScale) = (GVAR(lonMax) - GVAR(lonMin)) / worldSize;



// BELOW IS ONLY USED IF STRETCHING ACROSS FULL LATLON GRID OR FINDING PIXEL DIMENSIONS OF TERRAIN TO CALCULATE MAP IMAGE SIZE
// IDEA is 1m == 1px and can be scaled by percentage from there

// _kmEast is how many kilometers east to get to next major grid corner
_kmEast = [GVAR(latitudeBase), GVAR(longitudeBase), GVAR(latitudeBase), GVAR(longitudeBase) + 1] call FUNC(getLatLonDistance);
// _kmNorth is the same
_kmNorth = [GVAR(latitudeBase), GVAR(longitudeBase), GVAR(latitudeBase) + 1, GVAR(longitudeBase)] call FUNC(getLatLonDistance);
GVAR(botLeftLngLat) params ["_tempLon", "_tempLat"];
GVAR(topRightLngLat) params ["_tempLon2", "_tempLat2"];
// measure the map in km from west [0, 0] to east [worldSize, 0]
_arg = [_tempLat, _tempLon, _tempLat, _tempLon2] apply {(_x)};
_kmMapEast = _arg call FUNC(getLatLonDistance);
// measure the map in km from south [0, 0] to north [0, worldSize]
_arg = [_tempLat, _tempLon, _tempLat2, _tempLon] apply {(_x)};
_kmMapNorth = _arg call FUNC(getLatLonDistance);

// ONLY FOR STRETCHING
// divide to find out how much x/y need to be multiplied for everything to find full grid pos
// longitudeMultiplier = _kmEast / _kmMapEast;
// latitudeMultiplier = _kmNorth / _kmMapNorth;
// "debug_console" callExtension ("longitudeMultiplier = " + str(longitudeMultiplier));
// "debug_console" callExtension ("latitudeMultiplier = " + str(latitudeMultiplier));

// convert to meters instead of km, additional scaling if desired
_mMultiplier = {
	params [["_size", 1], ["_returnString", true]];
	_kmToM = 1;
	_scale = 20;
	_m = (_size * _kmToM);
	_scale = _m * _scale;
	if (_returnString) then {
		_scale toFixed 0
	} else {
		_scale
	};
};

"debug_console" callExtension ("_getOffset = " + str(_getOffset));
"debug_console" callExtension ("GVAR(longitudeOffset) = " + str(GVAR(longitudeOffset)));
"debug_console" callExtension ("GVAR(latitudeOffset) = " + str(GVAR(latitudeOffset)));
"debug_console" callExtension str([GVAR(botLeftLngLat), GVAR(topRightLngLat)]);
"debug_console" callExtension ("_kmEast = " + ([_kmEast] call _mMultiplier));
"debug_console" callExtension ("_kmNorth = " + ([_kmNorth] call _mMultiplier));
// FOR NORMAL IMAGE
"debug_console" callExtension ("_kmMapEast = " + ([_kmMapEast] call _mMultiplier));
"debug_console" callExtension ("_kmMapNorth = " + ([_kmMapNorth] call _mMultiplier));
"debug_console" callExtension ("emftoPngExportMultiplier = " + str(([_kmMapNorth, false] call _mMultiplier)/worldSize));
// FOR STRETCH IMAGE
// "debug_console" callExtension ("_kmMapEast = " + str(_kmMapEast * longitudeMultiplier));
// "debug_console" callExtension ("_kmMapNorth = " + str(_kmMapNorth * latitudeMultiplier));


// TO PREP TERRAIN IMAGE
/*
	1. Run Arma as admin
	2. Run export of map
	3. Check C:\mapname.emf was created
	4. Use EmfToPng binary with the noted export multiplier
		- EmfToPng.exe mapname.emf X (where X is the multiplier)
	5. Import resulting .png to GIMP
	6. Image > Scale Image to match the _kmMapEast (width) and _kmMapNorth (height) values
	7. Image > Mode > Precision 16-bit integer, select Perceptual Gamma (sRGB)
	8. Image > Canvas Size
		- Match _kmEast (width) and _kmNorth (height)
		- Drag the existing image to the bottom left -- X should be 0, and Y should be some value (measured from top of new canvas to top of existing map image)
		- Resize Layers = None
		- Fill With = Transparency
		- Hit Resize
	9. Set layer opacity to a medium value
		- Paint.NET - opacity to half of the bar
		- GIMP - 60%
	10. Scale the image down, if larger, until the largest dimension is 32168 pixels
	10. File > Export as..
		- Name should be something like N39E025.png, matching the bottom left Lat/Lon grid
		- PNG filetype
		- Click Export
	11. Export settings
		- Interlacing OFF
		- Save background color ON
		- Save gamma OFF
		- Save resolution ON
		- Save creation time ON
		- Save comment OFF
		- Save color values from transparent pixels OFF
		- Pixel format dropdown set to "8bpc RGBA"
		- Compression level 9
		- Save thumbnail ON
		- All other checkboxes at the bottom OFF
		- Click EXPORT
	12. Move the resulting .PNG to "C:\ProgramData\Tacview\Data\Terrain\Textures"

*/





// for exporting static objects XML
// call FUNC(terrainObjExport);
