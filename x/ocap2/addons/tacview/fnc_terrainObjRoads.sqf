#include "script_component.hpp"

params[
  [
    "_origin",
    [worldSize / 2, worldSize / 2]
  ],[
    "_sizeOfArea",
    1000
  ], [
    "_color",
    "#FFFFFFFF"
  ]
];

_list = _origin nearRoads _sizeOfArea;

_data = [];
_checkedRoads = [];

{
  private _posWorld = (_x modelToWorldVisualWorld [0,0,0]);
  private _lngLat = [_posWorld, longitudeMultiplier, latitudeMultiplier] call FUNC(getPosLngLat);
  private _alt = str((_posWorld # 2) + GVAR(altitudeOffset));
  private _pos = [_lngLat # 0, _lngLat # 1, _alt, _posWorld # 0, _posWorld # 1] joinString '|';
  private _type = "Object";
  private _shape = "Cube";
  private _size = [0,0,0];
  ((str _x) splitString ":") params ["_objectId", "_model"];

  (getRoadInfo _x) params [
    "_mapType",
    "_width",
    "_isPedestrian",
    "_texture",
    "_textureEnd",
    "_material",
    "_begPos",
    "_endPos",
    "_isBridge"
  ];

  switch (_mapType) do {
    case "ROAD": {
      _color = "#FFD966FF";
    };
    case "MAIN ROAD": {
      _color = "#FFFFFFFF";
    };
    case "TRACK": {
      _color = "#FF8099FF";
    };
    case "TRAIL": {
      _color = "#FF8099FF";
    };
    default {
      _color = "#FF8099FF";
    };
  };

  _nextNode = ( roadsConnectedTo _x ) select 0;
  // _dir = _posWorld getDir (_nextNode modelToWorldVisualWorld [0,0,0]);
  _dir = _begPos getDir _endPos;
  // _dir = _dir - 90;
  _pitch = ([_posWorld, _dir, 5 / 2] call BIS_fnc_terrainGradAngle);
  _angles = [];
  {
    _angles pushback ([_posWorld, _dir + _x, 5 / 2] call BIS_fnc_terrainGradAngle);
  } forEach [-90, 90];
  _roll = (_angles # 0 + _angles # 1) / 2;

  _bbr = boundingBoxReal _x;
  _br0 = _bbr select 0;
  _br1 = _bbr select 1;
  _maxwidth = abs ((_br1 select 0) - (_br0 select 0));
  _maxlength = abs ((_br1 select 1) - (_br0 select 1));

  _toSave = [
    "<Object ID=""" + _objectId + """>",
    "	<Position>",
    // "		<Latitude>" + ([_lngLat # 1, "N"] call fnc_DecToDMS) + "</Latitude>",
    // "		<Longitude>" + ([_lngLat # 0, "E"] call fnc_DecToDMS) + "</Longitude>",
    "		<Latitude>" + (_lngLat # 1) + "</Latitude>",
    "		<Longitude>" + (_lngLat # 0) + "</Longitude>",
    "		<Altitude>" + _alt + "</Altitude>",
    "	</Position>",
    "	<Shape>" + _shape + "</Shape>"
  ];

  private _height = 0.1;
  _toSave append [
    "	<Color>" + _color + "</Color>",
    "	<Size>",
    "		<Width>" + str(_maxwidth) + "</Width>",
    "		<Length>" + str(_maxlength) + "</Length>",
    "		<Height>" + str(_height) + "</Height>",
    "	</Size>",
    "	<Orientation>",
    "		<Roll>" + str(_roll) + "</Roll>",
    "		<Pitch>" + str(_pitch) + "</Pitch>",
    "		<Yaw>" + str(_dir) + "</Yaw>",
    "	</Orientation>",
    "</Object>"
  ];

  if !(_objectId in _checkedRoads) then {
    _data pushBack (_toSave joinString '
');
    _checkedRoads pushBackUnique _objectId;
  };

  // progressLoadingScreen (_forEachIndex / count _list);

  if (count _data > 30) then {
//       "debug_console" callExtension ((_data joinString '
// ') + "~0000");
    [_data joinString '
'] call FUNC(sendData);
    _data = nil;
    _data = [];
  };
} forEach _list;


// follow up
if (count _data > 0) then {
//     "debug_console" callExtension ((_data joinString '
// ') + "~0000");
  [_data joinString '
'] call FUNC(sendData);
  _data = nil;
  _data = [];
};
