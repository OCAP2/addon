#include "script_component.hpp"

// During postInit, we'll remoteExec these settings onto clients so vars are synchronized and modifiable during a mission.
{
  _x remoteExec ["CBA_fnc_addSetting", [0, -2] select isServer, true];
} forEach GVAR(allSettings);


ADDON = true;
