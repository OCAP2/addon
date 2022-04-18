#include "script_component.hpp"

params ["_frame", "_id", "_firerId", "_pos"];
_pos params ["_x", "_y", "_z"];
([_pos] call FUNC(getPosLngLat)) params ["_lon", "_lat"];

[[
  _id + 1,
  format ["T=%1|%2|%3|%4|%5", _lon toFixed 10, _lat toFixed 10, _z + GVAR(altitudeOffset), _x, _y],
  "Type=Projectile+Bullet",
  format["Parent=%1", _firerId + 1]
] joinString ","] call FUNC(sendData);
