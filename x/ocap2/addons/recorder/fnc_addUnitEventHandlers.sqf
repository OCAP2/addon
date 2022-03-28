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
  _entity addEventHandler ["FiredMan", { _this call FUNC(eh_firedMan); }];
};

// MPHIT
_entity addMPEventHandler ["MPHit", { _this spawn FUNC(eh_hit); }];

private _ownerId = owner _entity;
if (
  !_respawn && // exclude re-adding on respawn, as the CBA listener will already be present on the owner's machine
  (_entity call BIS_fnc_objectType) # 0 == "Soldier" &&
  _ownerId != 2 && // only add to entities not owned by server, as otherwise server will receive local events already
  isClass (configFile >> "CfgPatches" >> "ace_advanced_throwing")
) then {
  // here, we must place a local listener of ACE throw events on the owner of the entity
  // the client will then notify the server when these local events happen
  // we'll wait a max of 15 secs until that owner is at least to briefing stage, has completed PostInit, before sending
  [
    {(getUserInfo (_this#0)) select 6 > 8},
    {
      FUNC(aceThrowing) remoteExec ["call", _this#1];
      OCAPEXTLOG(ARR3("ADD ACE THROWING LISTENER", _this#0, _this#1));
    },
    [_ownerId, _entity],
    15
  ] call CBA_fnc_waitUntilAndExecute;
};
