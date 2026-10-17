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

  // WEAPONASSEMBLED / WEAPONDISASSEMBLED
  // Both fire only where the unit is local, so these cover units this machine
  // owns -- server AI. Players report the same two events through the client
  // bootstrap in <OCAP_recorder_fnc_installPlayerTrackingClients>, because a
  // handler added here would never fire on their machine.
  if (isNil {_entity getVariable QGVARMAIN(staticWeaponEH)}) then {
    _entity setVariable [
      QGVARMAIN(staticWeaponEH),
      _entity addEventHandler ["WeaponAssembled", {
        params ["_unit", "_static"];
        ["assembled", _unit, _static] call FUNC(submitStaticWeapon);
      }]
    ];
    // WeaponDisassembled hands over the two bags, not the gun, so this only
    // files the claim; the event is written when the gun disappears.
    _entity setVariable [
      QGVARMAIN(staticWeaponDisassembledEH),
      _entity addEventHandler ["WeaponDisassembled", {
        params ["_unit"];
        ["disassembled", _unit, objNull] call FUNC(submitStaticWeapon);
      }]
    ];
  };
};
