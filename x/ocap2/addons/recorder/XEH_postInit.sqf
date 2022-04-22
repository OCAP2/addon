#include "script_component.hpp"

{
  _x remoteExec ["CBA_fnc_addSetting", [0, -2] select isServer, true];
} forEach GVAR(allSettings);

if (!is3DEN) then {
  call FUNC(init);
};

ADDON = true;
