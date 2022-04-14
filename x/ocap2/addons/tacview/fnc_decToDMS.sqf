#include "script_component.hpp"

params ["_coord", "_EorN"];

// if (_coord isEqualType "") then {_coord = parseNumber(_coord)};

private _deg = floor(_coord);
private _latterpart = (_coord - _deg) * 60;
private _minutes = floor(_latterpart);
private _sec = (_latterpart - _minutes) * 60;

format["%1°%2'%3""%4", _deg, _minutes, _sec toFixed 10, _EorN];
