#include "script_component.hpp"

// "debug_console" callExtension ("_posLngLatParam = " + str(_this));
_eastNorthParam = param [0, [0.0,0.0]];
_longitudeMultiplier = param [1, 1];
_latitudeMultiplier = param [2, 1];

private ["_return"];
_eastNorth = _eastNorthParam select [0,2];
// "debug_console" callExtension ("_eastNorth = " + str(_eastNorth));
_eastNorth params ["_easting", "_northing"];
// for multiplying scale
// _easting = _easting * _latitudeMultiplier;
// _northing = _northing * _longitudeMultiplier;
// "debug_console" callExtension ("_eastNorth = " + str(_eastNorth));
// "debug_console" callExtension ("_newUTM = " + str(_newUTM));
private _lngLat = [_northing, _easting, GVAR(mapGrid)] call FUNC(UTMtoDeg);
// "debug_console" callExtension ("_lngLat = " + str(_lngLat));
_lngLat params ["_lon", "_lat"];
// _lngLat set [0, (((_lon - longitudeOffset) + (longitudeBase - floor(_lon)))) toFixed 10];
// "debug_console" callExtension ("_lon - longitudeOffset = " + str(_lon - longitudeOffset));
// "debug_console" callExtension ("longitudeBase = " + str(longitudeBase));
// "debug_console" callExtension ("floor(_lon) = " + str(floor(_lon)));
// "debug_console" callExtension ("_lngLat = " + str(_lngLat));
_lngLat set [0, ((_lon - longitudeOffset) + (longitudeBase - floor(_lon)) toFixed 10)];
// "debug_console" callExtension ("_lngLat # 0 = " + str(_lngLat # 0));
// "debug_console" callExtension ("_lon = " + str(_lon));
// "debug_console" callExtension ("longitudeOffset = " + str(longitudeOffset));
// "debug_console" callExtension ("longitudeBase = " + str(longitudeBase));
// "debug_console" callExtension ("_lngLat # 0 = " + str(_lngLat # 0));
_lngLat set [1, ((_lat - latitudeOffset + latitudeBase) toFixed 10)];
// "debug_console" callExtension ("_lat = " + str(_lat));
// "debug_console" callExtension ("latitudeOffset = " + str(latitudeOffset));
// "debug_console" callExtension ("latitudeBase = " + str(latitudeBase));
// "debug_console" callExtension ("_lngLat # 1 = " + str(_lngLat # 1));
_lngLat
