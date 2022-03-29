/* ----------------------------------------------------------------------------
Script: FUNC(addUnitEventHandlers)

Description:
  Used for applying unit-specific event handlers to units during initialization. These event handlers will trigger on the server.

  Applied during initialization of a unit in <FUNC(captureLoop)>.

Parameters:
  _entity - Object to apply event handlers to. [Object]
  _respawn - Determines if unit is initialized for the first time, or has respawned and does not need certain handlers reapplied. [Boolean, defaults to false]

Returns:
  Nothing

Examples:
  --- Code
  [_unit] spawn FUNC(addUnitEventHandlers);
  ---

Public:
  No

Author:
  IndigoFox, Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_entity", ["_respawn", false]];


// FIREDMAN
if ((_entity call BIS_fnc_objectType) # 0 == "Soldier") then {
  if (isNil {_entity getVariable QGVARMAIN(FiredManEH)}) then {
    _entity setVariable [
      QGVARMAIN(FiredManEH),
      _entity addEventHandler ["FiredMan", { _this call FUNC(eh_firedMan); }]
    ];
  };
};

// MPHIT
if (isNil {_entity getVariable QGVARMAIN(MPHitEH)}) then {
  _entity setVariable [
    QGVARMAIN(MPHitEH),
    _entity addMPEventHandler ["MPHit", { _this call FUNC(eh_hit); }]
  ];
};
