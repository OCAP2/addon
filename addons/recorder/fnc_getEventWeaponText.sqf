/* ----------------------------------------------------------------------------
FILE: fnc_getEventWeaponText.sqf

FUNCTION: OCAP_recorder_fnc_getEventWeaponText

Description:
  Used to identify the current weapon a unit is using that has injured or killed another. Will determine the handheld weapon or vehicle weapon they're using.

  Attempts to reference <OCAP_lastFired> but will fall back to current value if not available.

  Called during <OCAP_recorder_fnc_projectileHit> and <OCAP_recorder_fnc_eh_killed>.

Parameters:
  _instigator - The unit to evaluate [Object]

Returns:
  The description of weapon or vehicle > weapon. [String]

Examples:
  > [_shooter] call FUNC(getEventWeaponText)

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_instigator"];

if (isNull _instigator) exitWith {""};

if !(_instigator call CBA_fnc_isPerson) then {
  _instigator = _instigator call {
    if(alive(gunner _this))exitWith{gunner _this};
    if(alive(commander _this))exitWith{commander _this};
    if(alive(driver _this))exitWith{driver _this};
    effectiveCommander _this
  };
};

if (_instigator call CBA_fnc_isPerson) then {
  (_instigator weaponstate (currentWeapon _instigator)) params ["_weapon", "_muzzle", "_mode", "_magazine"];
  ([_weapon, _muzzle, _magazine] call FUNC(getWeaponDisplayData)) params ["_muzDisp", "_magDisp"];

  _instigator getVariable [
    QGVARMAIN(lastFired),
    format [
      "%1 [%2]",
      _muzDisp,
      _magDisp
    ]
  ];
} else {
  getText(configFile >> "CfgVehicles" >> (typeOf vehicle _instigator) >> "displayName");
};
