/* ----------------------------------------------------------------------------
FILE: fnc_isKindOfApc.sqf

FUNCTION: OCAP_recorder_fnc_isKindOfApc

Description:
  Helper function for <OCAP_recorder_fnc_getClass> to prevent APCs from being classified as Cars or Trucks.

Parameters:
  _this - The vehicle to check [Object]

Returns:
  [Bool] - True if the vehicle is an APC, false otherwise

Examples:
  > if (_this call FUNC(isKindOfApc)) exitWith {"apc"};

Public:
  No

Author:
  Dell, Zealot
---------------------------------------------------------------------------- */
#include "script_component.hpp"

_bool = false;
{
  if (_this isKindOf _x) exitWith {_bool = true;};
  false;
} count ["Wheeled_APC_F","Tracked_APC","APC_Wheeled_01_base_F","APC_Wheeled_02_base_F",
"APC_Wheeled_03_base_F","APC_Tracked_01_base_F","APC_Tracked_02_base_F","APC_Tracked_03_base_F"];
_bool
