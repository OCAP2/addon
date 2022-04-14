#include "script_component.hpp"

  // ["myLoadingScreen", "Getting objects..."] call BIS_fnc_startLoadingScreen;

  // header
//   "debug_console" callExtension ("
// <?xml version=""1.0"" encoding=""utf-8"" standalone=""yes""?>
// <Objects MapID=""Real World"">

// " + "~0000");
["
<?xml version=""1.0"" encoding=""utf-8"" standalone=""yes""?>
<Objects MapID=""Real World"">

"] call FUNC(sendData);


private _origin = position ((allUnits select {isPlayer _x}) # 0);
private _size = sqrt(worldSize * worldSize);
{
  _x call FUNC(terrainObjProcess)
} forEach [
  [
    _origin,
    _size,
    [
      "BUILDING",
      "HOUSE",
      "FORTRESS",
      "FOUNTAIN",
      "QUAY",
      "FUELSTATION",
      "BUSSTOP",
      "STACK",
      "RUIN",
      "TOURISM",
      "SHIPWRECK"
    ],
    "Cube",
    "#888888FF",
    2
  ],
  [
    _origin,
    _size,
    [
      "BUNKER",
      "VIEW-TOWER"
    ],
    "Cube",
    "#006600FF",
    3
  ],
  [
    _origin,
    _size,
    [
      // "POWER LINES",
      "POWERSOLAR",
      "POWERWAVE",
      "POWERWIND",
      "WATERTOWER"
    ],
    "Cube",
    "#0000660F",
    3
  ],
  [
    _origin,
    _size,
    [
      "CHURCH",
      "CHAPEL",
      "CROSS",
      "LIGHTHOUSE",
      "HOSPITAL"
    ],
    "Cube",
    "#FFFFFFFF",
    3
  ],
  // [
  // 	_origin,
  // 	_size,
  // 	[
  // 		"WALL",
  // 		"FENCE"
  // 	],
  // 	"Cube",
  // 	"#4444448EF",
  // 	3,
  // 	nil,
  // 	"Border"
  // ],
  [
    _origin,
    _size,
    [
      "SMALL TREE",
      "TREE"
    ],
    "Cone",
    "#22992250",
    3
  ],
  [
    _origin,
    _size,
    [
      "ROCKS",
      "ROCK"
    ],
    "Sphere",
    "#888888FF",
    3
  ],
  [
    _origin,
    _size,
    [
      "HIDE"
    ],
    "Cube",
    "#888888FF",
    0
  ]
];







/*

"ROAD"
"FOREST"
"TRANSMITTER"

"TRACK"
"MAIN ROAD"
"ROCK"
"ROCKS"

"RAILWAY"

"TRAIL"


WHITE
"CHURCH"
"CHAPEL"
"CROSS"
"LIGHTHOUSE"
"HOSPITAL"

BLUE
"POWER LINES"
"POWERSOLAR"
"POWERWAVE"
"POWERWIND"
"WATERTOWER"

GRAY
"BUILDING"
"HOUSE"
"FORTRESS"
"FOUNTAIN"
"QUAY"
"FUELSTATION"
"BUSSTOP"
"STACK"
"RUIN"
"TOURISM"
"SHIPWRECK"

GREEN
"BUNKER"
"VIEW-TOWER"

DARK GRAY
"FENCE"
"WALL"
"HIDE"

GREEN
"TREE"
"SMALL TREE"
"BUSH"

GREEN
"FOREST BORDER"
"FOREST TRIANGLE"
"FOREST SQUARE"

*/

// [_origin, _size] call fnc_getRoads;

//tail
//   "debug_console" callExtension ("
// </Objects>
// " + "~0000");

["
</Objects>
"] call FUNC(sendData);



// ["myLoadingScreen", "Finished"] call BIS_fnc_endLoadingScreen;

hint "Finished";
