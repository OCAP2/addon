#include "script_component.hpp"

_bool = false;
{
  if (_this isKindOf _x) exitWith {_bool = true;};
  false;
} count ["Wheeled_APC_F","Tracked_APC","APC_Wheeled_01_base_F","APC_Wheeled_02_base_F",
"APC_Wheeled_03_base_F","APC_Tracked_01_base_F","APC_Tracked_02_base_F","APC_Tracked_03_base_F"];
_bool
