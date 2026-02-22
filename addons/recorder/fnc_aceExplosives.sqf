/* ----------------------------------------------------------------------------
FILE: fnc_aceExplosives.sqf

FUNCTION: OCAP_recorder_fnc_aceExplosives

Description:
  Integrates ACE3-placed explosives into the placed object pipeline.
  Sends :NEW:PLACED: data and attaches lifecycle EHs (HitExplosion, Explode,
  Deleted) identical to vanilla mines in fnc_eh_fired_client.sqf.

  Called by <ace_explosives_place> CBA listener.

Parameters:
  _explosive - Object: the placed explosive
  _dir       - Number: direction
  _pitch     - Number: pitch
  _unit      - Object: the unit that placed the explosive

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

// Resolve explosive metadata from config
private _explType = typeOf _explosive;
private _explosiveMag = getText(configFile >> "CfgAmmo" >> _explType >> "defaultMagazine");
private _explosiveDisp = getText(configFile >> "CfgMagazines" >> _explosiveMag >> "displayName");
private _explosivePic = getText(configFile >> "CfgMagazines" >> _explosiveMag >> "picture");

// Get placer's OCAP ID
private _unitOcapId = _unit getVariable [QGVARMAIN(id), -1];
if (_unitOcapId isEqualTo -1) exitWith {};

_explosive setVariable [QGVARMAIN(detonated), false];

// Build :NEW:PLACED: data — same format as vanilla mines in fnc_eh_fired_client.sqf
private _placedData = [
  EGVAR(recorder,captureFrameNo),                                        // 0: captureFrameNo
  -1,                                                                     // 1: placedId (assigned by server)
  _explType,                                                              // 2: className
  _explosiveDisp,                                                         // 3: displayName
  (getPosASL _explosive) joinString ",",                                  // 4: position
  _unitOcapId,                                                            // 5: firerOcapId
  str (side group _unit),                                                 // 6: side
  "put",                                                                  // 7: weapon
  _explosivePic                                                           // 8: magazineIcon
];

[QGVARMAIN(handlePlacedData), [_placedData, _explosive]] call CBA_fnc_serverEvent;

// Attach lifecycle EHs — identical to vanilla path in fnc_eh_fired_client.sqf
_explosive addEventHandler ["HitExplosion", {
  params ["_explosive", "_hitEntity", "_explosiveOwner", "_hitThings"];
  if (isNull _hitEntity) exitWith {};
  if (count _hitThings isEqualTo 0) exitWith {};
  private _hitOcapId = _hitEntity getVariable [QGVARMAIN(id), -1];
  if (_hitOcapId isEqualTo -1) exitWith {};
  private _placedId = _explosive getVariable [QGVARMAIN(placedId), -1];
  private _eventData = [
    EGVAR(recorder,captureFrameNo),                                      // 0: captureFrameNo
    _placedId,                                                            // 1: placedId
    "hit",                                                                // 2: eventType
    (getPosASL _hitEntity) joinString ",",                                // 3: position (victim pos)
    _hitOcapId                                                            // 4: hitEntityOcapId
  ];
  [QGVARMAIN(handlePlacedEvent), [_eventData]] call CBA_fnc_serverEvent;
}];

_explosive addEventHandler ["Explode", {
  params ["_explosive", "_pos", "_velocity"];
  if (_explosive getVariable [QGVARMAIN(detonated), true]) exitWith {};
  _explosive setVariable [QGVARMAIN(detonated), true];
  private _placedId = _explosive getVariable [QGVARMAIN(placedId), -1];
  private _eventData = [
    EGVAR(recorder,captureFrameNo),                                      // 0: captureFrameNo
    _placedId,                                                            // 1: placedId
    "detonated",                                                          // 2: eventType
    _pos joinString ","                                                   // 3: position
  ];
  [QGVARMAIN(handlePlacedEvent), [_eventData]] call CBA_fnc_serverEvent;
}];

_explosive addEventHandler ["Deleted", {
  params ["_explosive"];
  // Only send "deleted" if not already detonated (avoid double-send)
  if (_explosive getVariable [QGVARMAIN(detonated), true]) exitWith {};
  _explosive setVariable [QGVARMAIN(detonated), true];
  private _placedId = _explosive getVariable [QGVARMAIN(placedId), -1];
  private _eventData = [
    EGVAR(recorder,captureFrameNo),                                      // 0: captureFrameNo
    _placedId,                                                            // 1: placedId
    "deleted",                                                            // 2: eventType
    (getPosASL _explosive) joinString ","                                 // 3: position
  ];
  [QGVARMAIN(handlePlacedEvent), [_eventData]] call CBA_fnc_serverEvent;
}];
