/* ----------------------------------------------------------------------------
Script: FUNC(aceExplosives)

Description:
  Listener for ACE3 global event indicating an armed mine has been placed.
  Adds marker on its position to the recording, not in-game.
  Then waits until the explosive is null (exploded) and indicates it with a temporary new marker in the recording.


Parameters:
  None

Returns:
  Nothing

Examples:
  --- Code
  call FUNC(aceExplosives);
  ---

Notes:
  ACE3 call
  [QGVAR(place), [_explosive, _dir, _pitch, _unit]] call CBA_fnc_globalEvent;

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

EGVAR(listener,aceExplosives) = ["ace_explosives_place", {

  if (!SHOULDSAVEEVENTS) exitWith {};

  params ["_explosive", "_dir", "_pitch", "_unit"];

  private _int = random(2000);

  _explType = typeOf _explosive;
  _explosiveMag = getText(configFile >> "CfgAmmo" >> _explType >> "defaultMagazine");
  _explosiveDisp = getText(configFile >> "CfgMagazines" >> _explosiveMag >> "displayName");

  _placedPos = getPosASL _explosive;
  _unit addOwnedMine _explosive;

  _markTextLocal = format["%1", _explosiveDisp];
  _markName = format["%1#%2/%3", QGVARMAIN(mine), _int, _placedPos];
  _markColor = "ColorRed";
  _markerType = "Minefield";

  if (GVARMAIN(isDebug)) then {
    format["Created explosive placed marker, %1, %2", _markName, _explosiveDisp] SYSCHAT;
    OCAPEXTLOG(ARR3("Created explosive placed marker", _markName, _explosiveDisp));
  };

  [QGVARMAIN(handleMarker), [
    "CREATED", _markName, _unit, _placedPos, _markerType, "ICON", [1,1], 0, "Solid", "ColorRed", 1, _markTextLocal, true
  ]] call CBA_fnc_localEvent;


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

    [QGVARMAIN(handleMarker), ["DELETED", _markName]] call CBA_fnc_localEvent;

    _markTextLocal = format["%1", _explosiveDisp];
    _markName = format["Detonation#%1", _int];
    _markColor = "ColorRed";
    _markerType = "waypoint";

    if (GVARMAIN(isDebug)) then {
      format["Created explosive explosion marker, %1, %2", _markName, _explosiveDisp] SYSCHAT;
      OCAPEXTLOG(ARR3("Created explosive explosion marker", _markName, _explosiveDisp));
    };

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
    }, [_markName, _explosiveDisp], 10] call CBA_fnc_waitAndExecute;

  }, [_explosive, _explosiveDisp, _unit, _placedPos, _markName, _int]] call CBA_fnc_waitUntilAndExecute;

}] call CBA_fnc_addEventHandler;
