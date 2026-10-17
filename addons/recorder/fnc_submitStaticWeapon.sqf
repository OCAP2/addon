/* ----------------------------------------------------------------------------
FILE: fnc_submitStaticWeapon.sqf

FUNCTION: OCAP_recorder_fnc_submitStaticWeapon

Description:
  Server-side trust boundary for static weapons being assembled from bags, and
  for a unit's claim to have taken one apart.

  The gun itself needs no help from this function: a newly created static weapon
  is picked up by <OCAP_recorder_fnc_captureLoop> like any other vehicle and gets
  its own entity record. What the recording is missing is the *act* -- who built
  it and when -- which is what the `staticWeapon` event adds, pointing at the
  vehicle id so the UI can tie the two together.

  Assembly signals are client-local and reach this function through the standard
  round trip described in AGENTS.md:

    - vanilla `WeaponAssembled`, which fires only where the assembling unit is
      local. The server registers it for its own AI in
      <OCAP_recorder_fnc_addUnitEventHandlers>; players register it through the
      client bootstrap in <OCAP_recorder_fnc_installPlayerTrackingClients>.
    - ACE3 CSW, which does not use the engine command at all. Its
      `ace_csw_deployWeaponSucceeded` is a local event on the deploying client,
      so the bootstrap listens for it and reports the local player as the builder.

  A freshly created static has no OCAP id until the next capture frame, so an
  assembly waits for one rather than recording -1 and losing the link to the
  entity record.

  Disassembly is not emitted here. `WeaponDisassembled` hands over the two bags
  and not the gun, which by then no longer exists, so there is nothing to point
  an event at. It is filed as a dated claim instead, and
  <OCAP_recorder_fnc_trackConstructions> matches it against the gun that actually
  disappears. That also covers ACE CSW's pickup action, which raises no event at
  all and leaves the sweep to fall back on the nearest unit.

  Remote callers must own the attributed unit; ids are then read here from the
  objects rather than the payload. Direct server calls still cover server AI.

Parameters:
  _action - "assembled" or "disassembled". [String]
  _unit   - The unit that did it. [Object]
  _static - The static weapon. Ignored, and normally objNull, for "disassembled". [Object]

Returns:
  Nothing

Examples:
  > ["assembled", player, _weapon] remoteExecCall [QFUNC(submitStaticWeapon), 2];

Public:
  No

Author:
  OCAP Improved
---------------------------------------------------------------------------- */
#include "script_component.hpp"

// How long to wait for the capture loop to hand the new gun an OCAP id.
#define STATIC_ID_TIMEOUT 15
// One assembly reported through two paths inside this window is one assembly.
#define STATIC_DEDUPE 5

if (!isServer) exitWith {};
if (!SHOULDSAVEEVENTS) exitWith {};
if (!EGVAR(extension,sessionReady)) exitWith {};
if (!(missionNamespace getVariable [QEGVAR(settings,trackConstructions), true])) exitWith {};

params [
  ["_action", "", [""]],
  ["_unit", objNull, [objNull]],
  ["_static", objNull, [objNull]]
];

if !(_action in ["assembled", "disassembled"]) exitWith {};
if (isNull _unit) exitWith {};
if (isMultiplayer && {isRemoteExecuted} && {remoteExecutedOwner isNotEqualTo owner _unit}) exitWith {};

private _unitId = _unit getVariable [QGVARMAIN(id), -1];
private _unitName = name _unit;
private _side = str (side group _unit);

// A disassembly claim is only half the story: the gun it refers to is already
// gone. Park it for the sweep, which fires the event once it sees which gun
// disappeared. Claims are pruned there by age.
if (_action isEqualTo "disassembled") exitWith {
  if (isNil QGVAR(staticDisassembleClaims)) then {GVAR(staticDisassembleClaims) = []};
  GVAR(staticDisassembleClaims) pushBack [_unitId, _unitName, _side, getPosASL _unit, CBA_missionTime];
};

if (isNull _static) exitWith {};

if (isNil QGVAR(staticWeaponSeen)) then {GVAR(staticWeaponSeen) = createHashMap};

private _now = CBA_missionTime;
private _key = str _static;
if (_now - (GVAR(staticWeaponSeen) getOrDefault [_key, -1e10]) < STATIC_DEDUPE) exitWith {};
GVAR(staticWeaponSeen) set [_key, _now];

// An entry is only ever read inside the STATIC_DEDUPE window that follows it, so
// anything older is dead weight. Without this the map keeps one entry per gun
// ever built for the length of the mission, which is a slow leak on a long
// operation. Swept here rather than on a timer: this is the only writer, and the
// map cannot grow while nothing is being assembled.
private _stale = [];
{
  if (_now - _y >= STATIC_DEDUPE) then {_stale pushBack _x};
} forEach GVAR(staticWeaponSeen);
{GVAR(staticWeaponSeen) deleteAt _x} forEach _stale;

private _class = typeOf _static;
// Never store a localized string in a recording -- see AGENTS.md.
private _name = getTextRaw (configFile >> "CfgVehicles" >> _class >> "displayName");
if (_name isEqualTo "" || {(_name select [0, 1]) isEqualTo "$"}) then {_name = _class};

private _emit = {
  params ["_static", "_unitId", "_unitName", "_side", "_class", "_name", "_recordingStart"];

  if (!SHOULDSAVEEVENTS) exitWith {};
  // A queued assembly must not carry old entity ids into a new recording.
  if ((missionNamespace getVariable [QGVAR(startTime), -1]) isNotEqualTo _recordingStart) exitWith {};

  private _vehicleId = -1;
  private _pos = [0, 0, 0];
  if (!isNull _static) then {
    _vehicleId = _static getVariable [QGVARMAIN(id), -1];
    _pos = getPosASL _static;
  };

  [":EVENT:GENERAL:", [
    GVAR(captureFrameNo) max 0,
    "staticWeapon",
    [createHashMapFromArray [
      // Always "assembled": the "disassembled" claim exits above and is written
      // by the sweep in <OCAP_recorder_fnc_trackConstructions>, which is the
      // only place that knows which gun actually vanished. Hardcoded rather than
      // read from _action so this cannot quietly start emitting the wrong verb
      // if that early exit is ever moved.
      ["action", "assembled"],
      ["unitId", _unitId],
      ["unitName", _unitName],
      ["side", _side],
      ["vehicleId", _vehicleId],
      ["class", _class],
      ["name", _name],
      ["x", round (_pos select 0)],
      ["y", round (_pos select 1)]
    ]] call FUNC(encodeJSON)
  ]] call EFUNC(extension,sendData);

  if (GVARMAIN(isDebug)) then {
    OCAPEXTLOG(ARR2("STATIC WEAPON assembled",_class));
  };
};

// The gun exists but the capture loop has not run since, so wait for the id and
// let the event point at the entity record. On timeout -- an excluded class, or
// a gun deleted again before it was ever captured -- write it anyway without one.
private _fnc_run = {
  private _emit = _this select 7;
  _this call _emit;
};

[
  {(_this select 0) getVariable [QGVARMAIN(id), -1] > -1},
  _fnc_run,
  [_static, _unitId, _unitName, _side, _class, _name, GVAR(startTime), _emit],
  STATIC_ID_TIMEOUT,
  _fnc_run
] call CBA_fnc_waitUntilAndExecute;
