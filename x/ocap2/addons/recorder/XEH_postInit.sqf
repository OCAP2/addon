#include "script_component.hpp"
#include "XEH_prep.sqf"

if (!EGVAR(settings,autoStart)) then {
  call FUNC(init);
};

ADDON = true;
