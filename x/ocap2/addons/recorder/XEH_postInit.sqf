#include "script_component.hpp"
#include "XEH_prep.sqf"

{
  _x remoteExec ["CBA_fnc_addSetting", [0, -2] select isDedicated, true];
} forEach GVAR(allSettings);

ADDON = true;
