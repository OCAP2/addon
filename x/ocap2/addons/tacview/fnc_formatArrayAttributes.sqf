#include "script_component.hpp"

params ["_prefix", "_values", ["_formatter", { _this }]];
_attributes = [];
{
  _attributes pushBack (format ["%1%2=%3", _prefix, _forEachIndex, _x call _formatter]);
} forEach _values;
_attributes;
