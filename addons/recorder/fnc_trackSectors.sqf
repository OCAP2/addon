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
if (_this isEqualType [] && {count _this > 0}) exitWith {
  params ["_sector"];
  if (_sector getVariable [QGVAR(sectorTracked), false]) exitWith {};
  _sector setVariable [QGVAR(sectorTracked), true];

  [_sector, "ownerChanged", {
    params ["_sector", "_newOwner", "_oldOwner"];
    if (!SHOULDSAVEEVENTS) exitWith {};

    private _name = _sector getVariable ["Name", ""];
    if (_name isEqualTo "") then { _name = vehicleVarName _sector };
    if (_name isEqualTo "") then { _name = str _sector };

    private _pos = getPosATL _sector;
    if (_newOwner isEqualTo sideUnknown) then {
      [QGVARMAIN(customEvent), ["contested", ["sector", _name, _pos]]] call CBA_fnc_localEvent;
    } else {
      [QGVARMAIN(customEvent), ["captured", ["sector", _name, _pos]]] call CBA_fnc_localEvent;
    };
  }] call BIS_fnc_addScriptedEventHandler;
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
