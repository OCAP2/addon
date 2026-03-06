/* ----------------------------------------------------------------------------
FILE: fnc_trackSectors.sqf

FUNCTION: OCAP_recorder_fnc_trackSectors

Description:
  Attaches OwnerChanged scripted event handlers to ModuleSector_F objects
  to automatically record sector capture events in the OCAP timeline.

  When called with [_sector], attaches tracking to that single sector.
  When called with no arguments, initializes tracking for all existing
  sectors and sets up Zeus monitoring for newly placed sectors.

Parameters:
  _sector - (optional) single sector to track [Object]

Returns:
  Nothing

Public:
  No

Author:
  Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

// --- Single-sector mode: attach EH to one sector ---
if (_this isEqualType []) exitWith {
  params ["_sector"];
  if (_sector getVariable [QGVAR(sectorTracked), false]) exitWith {};
  _sector setVariable [QGVAR(sectorTracked), true];

  _sector addEventHandler ["OwnerChanged", {
    params ["_sector", "_oldOwner", "_newOwner"];
    if (!SHOULDSAVEEVENTS) exitWith {};
    if (_newOwner isEqualTo sideUnknown) exitWith {};

    private _name = _sector getVariable ["Name", ""];
    if (_name isEqualTo "") then { _name = vehicleVarName _sector };
    if (_name isEqualTo "") then { _name = str _sector };

    [QGVARMAIN(customEvent), ["captured", format ["%1,sector", _name]]] call CBA_fnc_localEvent;
    INFO_3("Sector captured: %1 — %2 -> %3",_name,_oldOwner,_newOwner);
  }];
};

// --- Init mode: track all existing sectors + Zeus monitoring ---
if (!EGVAR(settings,trackSectors)) exitWith {
  OCAPEXTLOG(["Sector tracking disabled by setting"]);
};

private _sectors = entities "ModuleSector_F";
{ [_x] call FUNC(trackSectors) } forEach _sectors;
INFO_1("Tracking %1 existing sector(s)",count _sectors);

// Monitor Zeus-placed sectors
{
  _x addEventHandler ["CuratorObjectPlaced", {
    params ["_curator", "_object"];
    if (!(_object isKindOf "ModuleSector_F")) exitWith {};
    [_object] call FUNC(trackSectors);
    INFO_1("Zeus-placed sector tracked: %1",_object);
  }];
} forEach allCurators;
