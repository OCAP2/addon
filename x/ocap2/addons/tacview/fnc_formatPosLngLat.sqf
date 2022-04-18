#include "script_component.hpp"

params ["_object"];

getPosWorld _object params ["_x", "_y", "_z"];
_yaw = direction _object;
(_object call BIS_fnc_getPitchBank) params ["_pitch", "_roll"];
([[_x, _y]] call FUNC(getPosLngLat)) params ["_lon", "_lat"];

// See TV documentation for the difference between yaw and heading
// I don't think it makes much diff in the context of ARMA
_heading = _yaw;
format ["T=%1|%2|%3|%4|%5|%6|%7|%8|%9", _lon toFixed 10, _lat toFixed 10, _z + GVAR(altitudeOffset), _roll, _pitch, _yaw, _x, _y, _heading];

