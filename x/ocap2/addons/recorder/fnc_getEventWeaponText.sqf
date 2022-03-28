/* ----------------------------------------------------------------------------
Script: ocap_fnc_getEventWeaponText

Description:
  Used to identify the current weapon a unit is using that has injured or killed another. Will determine the handheld weapon or vehicle weapon they're using.

  Called during <FUNC(eh_hit)> and <FUNC(eh_killed)>.

Parameters:
  _instigator - The unit to evaluate [Object]

Returns:
  The description of weapon or vehicle > weapon. [String]

Examples:
  --- Code
  [_instigator] call ocap_fnc_getEventWeaponText
  ---

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_instigator"];

if (vehicle _instigator isEqualTo _instigator) exitWith {
  _instigator getVariable [
    QGVARMAIN(lastFired),
    format[
      "%1 [%2]",
      getText (configFile >> "CfgWeapons" >> currentWeapon _instigator >> "displayName"),
      getText (configFile >> "CfgWeapons" >> currentMuzzle _instigator >> "displayName")
    ]
  ]
};

// pilot/driver doesn't return a value, so check for this
private _turPath = [];
if (count (assignedVehicleRole _instigator) > 1) then {
  _turPath = assignedVehicleRole _instigator select 1;
} else {
  _turPath = [-1];
};

private _curVic = getText(configFile >> "CfgVehicles" >> (typeOf vehicle _instigator) >> "displayName");
(weaponstate [vehicle _instigator, _turPath]) params ["_curWep", "_curMuzzle", "_curFiremode", "_curMag"];
private _curWepDisplayName = getText(configFile >> "CfgWeapons" >> _curWep >> "displayName");
private _curMagDisplayName = getText(configFile >> "CfgMagazines" >> _curMag >> "displayName");
private _text = _curVic;
if (count _curMagDisplayName < 22) then {
  if !(_curWepDisplayName isEqualTo "") then {
    _text = _text + " [" + _curWepDisplayName;
    if !(_curMagDisplayName isEqualTo "") then {
      _text = _text + " / " + _curMagDisplayName + "]";
    } else {
      _text = _text + "]"
    };
  };
} else {
  if !(_curWepDisplayName isEqualTo "") then {
    _text = _text + " [" + _curWepDisplayName;
    if (_curWep != _curMuzzle && !(_curMuzzle isEqualTo "")) then {
      _text = _text + " / " + _curMuzzle + "]";
    } else {
      _text = _text + "]";
    };
  };
};

_text;
