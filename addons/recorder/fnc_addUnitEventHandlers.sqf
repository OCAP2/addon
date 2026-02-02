/* ----------------------------------------------------------------------------
FILE: fnc_addUnitEventHandlers.sqf

FUNCTION: OCAP_recorder_fnc_addUnitEventHandlers

Description:
  Used for applying unit-specific event handlers to units during initialization. These event handlers will trigger on the server.

  Applied during initialization of a unit in <OCAP_recorder_fnc_captureLoop>.

  Note: Hit tracking moved to projectile EHs in <OCAP_recorder_fnc_eh_firedMan>

Parameters:
  _entity - Object to apply event handlers to. [Object]
  _respawn - Determines if unit is initialized for the first time, or has respawned and does not need certain handlers reapplied. [[Bool], default: false]

Returns:
  Nothing

Examples:
  > [_unit] spawn FUNC(addUnitEventHandlers);

Public:
  No

Author:
  IndigoFox, Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_entity", ["_respawn", false]];


// FIREDMAN
// Set a serverside variable on the unit with a value of the handle of the FiredMan EH placed on that unit.
if ((_entity call BIS_fnc_objectType) # 0 == "Soldier") then {
  if (isNil {_entity getVariable QGVARMAIN(FiredManEH)}) then {
    _entity setVariable [
      QGVARMAIN(FiredManEH),
      _entity addEventHandler ["FiredMan", { _this call FUNC(eh_firedMan); }]
    ];
  };
};
