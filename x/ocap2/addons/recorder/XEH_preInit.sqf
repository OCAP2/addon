#include "script_component.hpp"
#include "XEH_prep.sqf"

if (EGVAR(settings,autoStart) && !is3DEN) then {
  call FUNC(init);
};

ADDON = true;
