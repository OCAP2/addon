#include "script_component.hpp"

params ["_frame", ["_isEnd", 0, [0]], "_id", "_firer", "_firerId", "_pos", "_projType", "_ammoSimType", "_wepString"];
_pos params ["_x", "_y", "_z"];
([_pos] call FUNC(getPosLngLat)) params ["_lon", "_lat"];

_ammoSimType = toLowerANSI _ammoSimType;
if (_ammoSimType == "shotsmokex" && _projType find "light" > -1) then {
  _ammoSimType = "shotilluminating";
};
_typeData = GVAR(projectileTypeCache) getOrDefault [_ammoSimType, ["Misc+Minor", false]];

if !([false, true] select _isEnd) then {
  // if START, draw
  [[
    _id + 1,
    format ["T=%1|%2|%3|%4|%5", _lon toFixed 10, _lat toFixed 10, _z + GVAR(altitudeOffset), _x, _y],
    format["Color=%1", [_firer] call FUNC(getColor)],
    format["Label=%1", _wepString],
    format["Type=%1", _typeData#0],
    format["Radius=%1", [_projType, _ammoSimType] call FUNC(getAmmoRadius)],
    format["Parent=%1", _firerId+1]
  ] joinString ","] call FUNC(sendData);
} else {
  // if END, do effect
  switch (_typeData#1) do {
    case 0: {
      // no effect
      [[
        _id + 1,
        format ["T=%1|%2|%3|%4|%5", _lon toFixed 10, _lat toFixed 10, _z + GVAR(altitudeOffset), _x, _y],
        "Visible=0"
      ] joinString ","] call FUNC(sendData);
    };
    case 1: {
      // explosion
      [[
        _id + 1,
        format ["T=%1|%2|%3|%4|%5", _lon toFixed 10, _lat toFixed 10, _z + GVAR(altitudeOffset), _x, _y],
        "Type=Misc+Explosion",
        format["Parent=%1", _firerId + 1]
      ] joinString ","] call FUNC(sendData);

      [{
        [[
          _this + 1,
          "Visible=0"
        ] joinString ","] call FUNC(sendData);
      }, _id , 3] call CBA_fnc_waitAndExecute;
    };
    case 2: {
      // smoke
      [[
        _id + 1,
        format ["T=%1|%2|%3|%4|%5", _lon toFixed 10, _lat toFixed 10, _z + GVAR(altitudeOffset), _x, _y],
        "Type=Misc+Decoy",
        format["Parent=%1", _firerId + 1],
        format["Radius=%1", [_projType, _ammoSimType] call FUNC(getAmmoRadius)]
      ] joinString ","] call FUNC(sendData);

      [{
        [[
          _this + 1,
          "Visible=0"
        ] joinString ","] call FUNC(sendData);
      }, _id , 3] call CBA_fnc_waitAndExecute;
    };
  };
};
