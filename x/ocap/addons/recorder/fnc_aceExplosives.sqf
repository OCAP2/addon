/* ----------------------------------------------------------------------------
FILE: fnc_aceExplosives.sqf

FUNCTION: OCAP_recorder_fnc_aceExplosives

Description:
  Adds marker on the mine's position to the recording timeline.
  Then waits until the explosive is null (exploded) and indicates it with a 10-frame long red X before removing the marker.

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

_explType = typeOf _explosive;
_explosiveMag = getText(configFile >> "CfgAmmo" >> _explType >> "defaultMagazine");
_explosiveDisp = getText(configFile >> "CfgMagazines" >> _explosiveMag >> "displayName");
_explosivePic = getText(configFile >> "CfgMagazines" >> _explosiveMag >> "picture");

_placedPos = getPosASL _explosive;
_unit addOwnedMine _explosive;

_markTextLocal = format["%1", _explosiveDisp];
_markName = format["%1#%2/%3", QGVARMAIN(mine), _int, _placedPos];
_markColor = "ColorRed";
_markerType = "Minefield";


// Signals creation of a Minefield (triangle) marker on the timeline at the location the explosive was armed.
[QGVARMAIN(handleMarker), [
  "CREATED", _markName, _unit, _placedPos, _markerType, "ICON", [1,1], 0, "Solid", "ColorRed", 1, _markTextLocal, true
]] call CBA_fnc_localEvent;

if (GVARMAIN(isDebug)) then {
  // add to map draw array
  private _debugArr = [_explosive, _explosivePic, format["%1 %2 - %3", str side group _unit, name _unit, _markTextLocal], [side group _unit] call BIS_fnc_sideColor];
  GVAR(liveDebugMagIcons) pushBack _debugArr;
  publicVariable QGVAR(liveDebugMagIcons);
};


[{isNull (_this#0)}, { // wait until the mine is null (exploded), and mark this for playback

  params ["_explosive", "_explosiveDisp", "_unit", "_placedPos", "_markName", "_int"];

  // set unit who placed's lastFired var as the explosive so kills are registered to the explosive
  _unit setVariable [
    QGVARMAIN(lastFired),
    _explosiveDisp
  ];

  // remove previous marker
  if (GVARMAIN(isDebug)) then {
    format["Removed explosive placed marker, %1, %2", _markName, _explosiveDisp] SYSCHAT;
    OCAPEXTLOG(ARR3("Removed explosive placed marker", _markName, _explosiveDisp));
  };


  // Signals removal of the Minefield (triangle) marker when the explosive is null (exploded).
  [QGVARMAIN(handleMarker), ["DELETED", _markName]] call CBA_fnc_localEvent;

  _markTextLocal = format["%1", _explosiveDisp];
  _markName = format["Detonation#%1", _int];
  _markColor = "ColorRed";
  _markerType = "waypoint";

  if (GVARMAIN(isDebug)) then {
    format["Created explosive explosion marker, %1, %2", _markName, _explosiveDisp] SYSCHAT;
    OCAPEXTLOG(ARR3("Created explosive explosion marker", _markName, _explosiveDisp));
  };


  // Signals creation of a Waypoint (X) marker on the timeline at the location the explosive detonated.
  [QGVARMAIN(handleMarker), [
    "CREATED", _markName, _unit, _placedPos, _markerType, "ICON", [1,1], 0, "Solid", "ColorRed", 1, _markTextLocal, true
  ]] call CBA_fnc_localEvent;


  [{
    params ["_markName", "_explosiveDisp"];
    if (GVARMAIN(isDebug)) then {
      format["Removed explosive explosion marker, %1, %2", _markName, _explosiveDisp] SYSCHAT;
      OCAPEXTLOG(ARR3("Removed explosive explosion marker", _markName, _explosiveDisp));
    };
    [QGVARMAIN(handleMarker), ["DELETED", _markName]] call CBA_fnc_localEvent;
  }, [_markName, _explosiveDisp], GVAR(captureFrameNo) * 10] call CBA_fnc_waitAndExecute;

}, [_explosive, _explosiveDisp, _unit, _placedPos, _markName, _int]] call CBA_fnc_waitUntilAndExecute;
