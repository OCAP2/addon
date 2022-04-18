#include "script_component.hpp"

params[
  [
    "_origin",
    [worldSize / 2, worldSize / 2]
  ],[
    "_sizeOfArea",
    sqrt(worldSize * worldSize)
  ],
  ["_typesToGather", []],
  "_shapeParam",
  "_color",
  "_clippingType",
  ["_overrideHeight", false],
  ["_xmlType", "Object"]
];


_shouldIgnore = {
  params ["_obj"];
  private _size = (boundingBox _obj) select 2;

  _size < 2
};
_objects = nearestTerrainObjects[
  // [worldSize / 2, worldSize / 2],
  _origin,
  _typesToGather,
  // worldSize * sqrt 2 / 2,
  _sizeOfArea,
  false
];

if(!isNil "_objects") then {
  _data = [];
  {


    // _data pushBack '{"objectid":"' + _objectid + '","model":"' + _model + '","posx":"' + str(_posx) + '","posy":"' + str(_posy) + '"}';
    // "debug_console" callExtension ('{"objectid":"' + _objectid + '","model":"' + _model + '","posx":"' + str(_posx) + '","posy":"' + str(_posy) + '"}');
    // "debug_console" callExtension (format["%1", boundingBoxReal _x] + "~0000");

    private _posWorld = (_x modelToWorldVisualWorld [0,0,0]);
    private _lngLat = [_posWorld, longitudeMultiplier, latitudeMultiplier] call FUNC(getPosLngLat);
    private _alt = str((_posWorld # 2) + GVAR(altitudeOffset));
    private _pos = [_lngLat # 0, _lngLat # 1, _alt, _posWorld # 0, _posWorld # 1] joinString '|';
    private _type = "Object";
    private _size = [0,0,0];
    private _objectScale = getObjectScale _x;
    ((str _x) splitString ":") params ["_objectid", "_model"];
    private _ID = _objectid;
    (_x call BIS_fnc_getPitchBank) params ["_pitch", "_roll"];
    _roll = deg(_roll);
    _roll = (vectorUp _x) # 0;
    (_x call CBA_fnc_viewDir) params ["_azimuth", "_inclination"];
    private _dir = getDirVisual _x;
    // private _dir = getDir _x;

    private ["_mins", "_maxs", "_sphereDiam"];
    if ("BUILDING" in _typesToGather) then {
      private _t = (_clippingType boundingBoxReal _x);
      _maxs = _t # 1;
    } else {
      private _t = boundingBox _x;
      _maxs = _t # 1;
    };

    (_maxs apply {(_x * _objectScale) * 2}) params ["_xMax", "_yMax", "_zMax"];
    // (_maxs apply {_x * 2}) params ["_xMax", "_yMax", "_zMax"];

    _save = true;
    // if (
    // 	(
    // 		"HIDE" in _typesToGather ||
    // 		"ROCKS" in _typesToGather
    // 	) && (
    // 		_xMax / 2 > _yMax ||
    // 		_yMax / 2 > _xMax
    // 	)
    // ) then {_shape = "Sphere"};

    private _shape = "Cube";

    if ("HIDE" in _typesToGather && (_xMax * _yMax) > 75) then {
      // _save = false
      _shape = "Sphere";
    } else {
      _shape = _shapeParam;
    };
    if ([_x] call _shouldIgnore) then {_save = false};
    // if (
    // 	"HIDE" in _typesToGather &&
    // 	(
    // 		["rocks", (getModelInfo _x) # 1] call BIS_fnc_inString ||
    // 		["mound", (getModelInfo _x) # 1] call BIS_fnc_inString
    // 	)
    // ) then {
    // 	_shape = "Sphere";
    // };
    private _toSave = "";

    if (_xmlType == "Border") then {
      _toSave = [
        "<" + _xmlType + " ID=""" + _ID + """>",
        "	<Color>" + _color + "</Color>",
        "	<Height>" + str(_height) + "</Height>",
        "	<Point>",
        "		<Latitude>" + str(_roll) + "</Latitude>",
        "		<Longitude>" + str(_inclination) + "</Longitude>",
        "		<Altitude>" + str(_azimuth) + "</Altitude>",
        "	</Point>",
        "</" + _xmlType + ">"
      ];
    } else {

      _toSave = [
        "<" + _xmlType + " ID=""" + _ID + """>",
        "	<Position>",
        // "		<Latitude>" + ([parseNumber(_lngLat # 1), "N"] call fnc_DecToDMS) + "</Latitude>",
        // "		<Longitude>" + ([parseNumber(_lngLat # 0), "E"] call fnc_DecToDMS) + "</Longitude>",
        "		<Latitude>" + (_lngLat # 1) + "</Latitude>",
        "		<Longitude>" + (_lngLat # 0) + "</Longitude>",
        "		<Altitude>" + _alt + "</Altitude>",
        "	</Position>",
        "	<Shape>" + _shape + "</Shape>"
      ];

      if (_shape == "Cone") then {
        _toSave append [
          "	<Color>" + _color + "</Color>",
          "	<Size>",
          "		<Width>" + "5" + "</Width>",
          "		<Length>" + str(_zMax) + "</Length>",
          "		<Height>" + "5" + "</Height>",
          "	</Size>",
          "	<BaseSize>",
          "		<Width>0</Width>",
          "		<Height>0</Height>",
          "	</BaseSize>",
          "	<Orientation>",
          "		<Roll>" + str(_roll) + "</Roll>",
          "		<Pitch>" + "-90" + "</Pitch>",
          "		<Yaw>" + "0" + "</Yaw>",
          "	</Orientation>",
          "</" + _xmlType + ">"
        ];
      } else {
        private _height = _zMax;
        if (_overrideHeight) then {_height = 1};
        _toSave append [
          "	<Color>" + _color + "</Color>",
          "	<Size>",
          "		<Width>" + str(_xMax) + "</Width>",
          "		<Length>" + str(_yMax) + "</Length>",
          "		<Height>" + str(_height) + "</Height>",
          "	</Size>",
          "	<Orientation>",
          "		<Roll>" + str(_roll) + "</Roll>",
          "		<Pitch>" + str(_inclination) + "</Pitch>",
          "		<Yaw>" + str(_azimuth) + "</Yaw>",
          "	</Orientation>",
          "</" + _xmlType + ">"
        ];
      };
    };

    if (_save) then {
      _data pushBack (_toSave joinString EOL);
    };

    // progressLoadingScreen (_forEachIndex / count _objects);

    if (count _data > 30) then {
      // "debug_console" callExtension ((_data joinString '
// ') + "~0000");
      {_x call FUNC(sendData)} forEach _data;
      _data = nil;
      _data = [];
    };
  } foreach _objects;

};
