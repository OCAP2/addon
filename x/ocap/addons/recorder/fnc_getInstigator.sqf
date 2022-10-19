/* ----------------------------------------------------------------------------
FILE: fnc_getInstigator.sqf

FUNCTION: OCAP_recorder_fnc_getInstigator

Description:
  Attempts to identify who truly pulled the trigger on a kill event.

  Called in <OCAP_recorder_fnc_eh_killed>.

Parameters:
  _victim - Who was killed. [Object]
  _killer - What caused the damage. [Object, default objNull]
  _instigator - Who pulled the trigger, as reported by Arma. [Object, default objNull]

Returns:
  The true killer. [Object]

Examples:
  > [_victim, _killer] call FUNC(getInstigator);

Public:
  No

Author:
  Dell
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params [["_victim", objNull], ["_killer", objNull], ["_instigator", objNull]];

if (isNull _instigator) then {
  _instigator = UAVControl vehicle _killer select 0;
};
if ((isNull _instigator) || (_instigator == _victim)) then {
  _instigator = _killer;
};
if (_instigator isKindOf "AllVehicles") then {
  _instigator = _instigator call {
    if(alive(gunner _this))exitWith{gunner _this};
    if(alive(commander _this))exitWith{commander _this};
    if(alive(driver _this))exitWith{driver _this};
    effectiveCommander _this
  };
};
if (isNull _instigator) then {
  _instigator = _killer;
};

_instigator;
