/* ----------------------------------------------------------------------------
FILE: fnc_getStaticObjects.sqf

FUNCTION: OCAP_database_fnc_getStaticObjects

Description:

  This function runs in the scheduled environment and will grab information about all non-terrain static objects on the map for reference, saving them to the database.

Parameters:
  None

Returns:
  Nothing

Examples:
  >  call FUNC(getStaticObjects);

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */


// WIP
if (!isServer) exitWith {};

// check if can sleep
if (!canSuspend) exitWith {};

// get all static buildings
private _userPlacedBuildings = 8 allObjects 0;

// loop through all objects
{
  private _pos = getPosWorld _x;
  private _dir = getDir _x;
  private _type = typeOf _x;
  private _config = configOf _x;

} forEach _userPlacedBuildings;
