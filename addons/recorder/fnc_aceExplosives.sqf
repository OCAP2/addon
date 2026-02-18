/* ----------------------------------------------------------------------------
FILE: fnc_aceExplosives.sqf

FUNCTION: OCAP_recorder_fnc_aceExplosives

Description:
  Adds marker on the mine's position to the recording timeline.
  Uses Explode event handler to detect detonation and indicates it with a 10-frame long red X before removing the marker.

  Called by <ace_explosives_place> CBA listener.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(aceExplosives);

Notes:
  Example of emitting event from ACE3 code:
  > [QGVAR(place), [_explosive, _dir, _pitch, _unit]] call CBA_fnc_globalEvent;

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {};

params ["_explosive", "_dir", "_pitch", "_unit"];

private _int = random(2000);

private _explType = typeOf _explosive;
private _explosiveMag = getText(configFile >> "CfgAmmo" >> _explType >> "defaultMagazine");
private _explosiveDisp = getText(configFile >> "CfgMagazines" >> _explosiveMag >> "displayName");
private _explosivePic = getText(configFile >> "CfgMagazines" >> _explosiveMag >> "picture");

private _placedPos = getPosASL _explosive;
_unit addOwnedMine _explosive;

private _markTextLocal = format["%1", _explosiveDisp];
private _markName = format["%1#%2/%3", QGVARMAIN(mine), _int, _placedPos];

// Signals creation of a Minefield (triangle) marker on the timeline at the location the explosive was armed.
[QGVARMAIN(handleMarker), [
  "CREATED", _markName, _unit, _placedPos, "Minefield", "ICON", [1,1], 0, "Solid", "ColorRed", 1, _markTextLocal, true
]] call CBA_fnc_localEvent;

if (GVARMAIN(isDebug)) then {
  private _msg = localize LSTRING(ExplosivePlacedMarkerCreated);
  format["%1, %2, %3", _msg, _markName, _explosiveDisp] SYSCHAT;
  OCAPEXTLOG(ARR3(_msg, _markName, _explosiveDisp));
  private _debugArr = [_explosive, _explosivePic, format["%1 %2 - %3", str side group _unit, name _unit, _markTextLocal], [side group _unit] call BIS_fnc_sideColor];
  GVAR(liveDebugMagIcons) pushBack _debugArr;
  publicVariable QGVAR(liveDebugMagIcons);
};

// Use Explode event handler instead of polling for null
_explosive addEventHandler ["Explode", {
  params ["_explosive", "_damage", "_source", "_instigator"];

  private _data = _explosive getVariable [QGVAR(explosiveData), []];
  if (_data isEqualTo []) exitWith {};

  _data params ["_explosiveDisp", "_unit", "_placedPos", "_markName", "_int"];

  if (GVARMAIN(isDebug)) then {
    private _msg = localize LSTRING(ExplosivePlacedMarkerRemoved);
    format["%1, %2, %3", _msg, _markName, _explosiveDisp] SYSCHAT;
    OCAPEXTLOG(ARR3(_msg, _markName, _explosiveDisp));
  };

  // Signals removal of the Minefield (triangle) marker when the explosive detonates
  [QGVARMAIN(handleMarker), ["DELETED", _markName]] call CBA_fnc_localEvent;

  private _detonationMarkName = format["Detonation#%1", _int];

  if (GVARMAIN(isDebug)) then {
    private _msg = localize LSTRING(ExplosionMarkerCreated);
    format["%1, %2, %3", _msg, _detonationMarkName, _explosiveDisp] SYSCHAT;
    OCAPEXTLOG(ARR3(_msg, _detonationMarkName, _explosiveDisp));
  };

  // Signals creation of a Waypoint (X) marker on the timeline at the location the explosive detonated
  [QGVARMAIN(handleMarker), [
    "CREATED", _detonationMarkName, _unit, _placedPos, "waypoint", "ICON", [1,1], 0, "Solid", "ColorRed", 1, format["%1", _explosiveDisp], true
  ]] call CBA_fnc_localEvent;

  [{
    params ["_markName", "_explosiveDisp"];
    if (GVARMAIN(isDebug)) then {
      private _msg = localize LSTRING(ExplosionMarkerRemoved);
      format["%1, %2, %3", _msg, _markName, _explosiveDisp] SYSCHAT;
      OCAPEXTLOG(ARR3(_msg, _markName, _explosiveDisp));
    };
    [QGVARMAIN(handleMarker), ["DELETED", _markName]] call CBA_fnc_localEvent;
  }, [_detonationMarkName, _explosiveDisp], GVAR(captureFrameNo) * 10] call CBA_fnc_waitAndExecute;
}];

// Store data on the explosive for retrieval in the event handler
_explosive setVariable [QGVAR(explosiveData), [_explosiveDisp, _unit, _placedPos, _markName, _int]];
