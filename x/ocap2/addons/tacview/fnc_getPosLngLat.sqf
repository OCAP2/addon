#include "script_component.hpp"

(_this#0) params ["_x", "_y"];

_lon = GVAR(lonMin) + (_x * GVAR(lonScale));
_lat = GVAR(latMin) + (_y * GVAR(latScale));
[_lon, _lat];
