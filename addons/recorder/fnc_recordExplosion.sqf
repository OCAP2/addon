/* ----------------------------------------------------------------------------
FILE: fnc_recordExplosion.sqf

FUNCTION: OCAP_recorder_fnc_recordExplosion

Description:
  Server-side trust boundary for detonations. Turns a raw "this ammo exploded
  here" report into an additive `explosion` general event carrying the blast
  radius, so playback can draw the affected area rather than a bare impact dot.

  The report can come from three places, all of which already exist:

    - a tracked non-bullet projectile's "Explode" event handler
      (<OCAP_recorder_fnc_eh_fired_clientProjectile>), which runs on the
      projectile owner's machine,
    - a placed mine's "Explode" handler in <OCAP_recorder_fnc_eh_fired_client>
      and its server-side counterpart in <OCAP_recorder_fnc_eh_fired_server>,
    - an ACE3 explosive's "Explode" handler in <OCAP_recorder_fnc_aceExplosives>.

  None of those carry the blast size, so radius and damage are read here from
  CfgAmmo and cached: an artillery barrage detonates the same class hundreds of
  times and the config lookup is the only expensive part.

  Attribution is resolved here rather than trusted from the caller. A projectile
  report passes the temp key it was tracked under and the firer is taken from
  <OCAP_recorder_trackedProjectiles>; everything else passes an OCAP id that is
  re-read from the object where one is available.

  Blasts smaller than <OCAP_settings_explosionMinRadius> are dropped, which is
  what keeps 20 mm HE cannon bursts from burying the event feed.

Parameters:
  _frame  - Capture frame the detonation happened on. [Number]
  _pos    - Detonation position, "x,y,z" as sent by the event handlers. [String or Array]
  _ammo   - CfgAmmo class of whatever exploded. [String]
  _firerId - OCAP id of the firer, or -1 when unknown. [Number, default: -1]
  _tempKey - Projectile tracking key, "" for anything not a tracked projectile. [String, default: ""]
  _source - "projectile" or "explosive". [String, default: "projectile"]

Returns:
  Nothing

Examples:
  > [GVAR(captureFrameNo), "1234,5678,12", "Sh_155mm_AMOS", -1, _tempKey] call FUNC(recordExplosion);

Public:
  No

Author:
  OCAP Improved
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!isServer) exitWith {};
if (!SHOULDSAVEEVENTS) exitWith {};
if (!EGVAR(extension,sessionReady)) exitWith {};
if (!(missionNamespace getVariable [QEGVAR(settings,trackExplosions), true])) exitWith {};

params [
  ["_frame", -1, [0]],
  ["_pos", "", ["", []]],
  ["_ammo", "", [""]],
  ["_firerId", -1, [0]],
  ["_tempKey", "", [""]],
  ["_source", "projectile", [""]]
];

if (_ammo isEqualTo "") exitWith {};

// VARIABLE: OCAP_recorder_explosionConfigCache
// CfgAmmo lookups keyed by ammo class: [radius, damage, english name]. A single
// mortar mission fires the same class dozens of times and the config read is the
// only part of this function that is not arithmetic.
if (isNil QGVAR(explosionConfigCache)) then {GVAR(explosionConfigCache) = createHashMap};

private _info = GVAR(explosionConfigCache) get _ammo;
if (isNil "_info") then {
  private _cfg = configFile >> "CfgAmmo" >> _ammo;
  private _radius = getNumber (_cfg >> "indirectHitRange");
  private _damage = getNumber (_cfg >> "indirectHit");

  // Never store a localized string in a recording, see FUNC(getConfigDisplayName).
  // An ammo without a usable name tries its default magazine, then falls back
  // to the class name, which is English by construction.
  private _name = [_cfg] call FUNC(getConfigDisplayName);
  if (_name isEqualTo "") then {
    private _mag = getText (_cfg >> "defaultMagazine");
    if (_mag isNotEqualTo "") then {
      _name = [configFile >> "CfgMagazines" >> _mag] call FUNC(getConfigDisplayName);
    };
  };
  if (_name isEqualTo "") then {_name = _ammo};

  _info = [_radius, _damage, _name];
  GVAR(explosionConfigCache) set [_ammo, _info];
};

_info params ["_radius", "_damage", "_name"];

private _minRadius = missionNamespace getVariable [QEGVAR(settings,explosionMinRadius), 2];
if (_radius < _minRadius) exitWith {};

// The event handlers all send "x,y,z"; accept a raw array too so a caller that
// already has one does not have to stringify it first.
private _coords = _pos;
if (_pos isEqualType "") then {
  _coords = (_pos splitString ",") apply {parseNumber _x};
};
if (count _coords < 2) exitWith {};

// A projectile report knows only the key it was tracked under. The firer, the
// vehicle it was fired from and the side all live in the tracked entry, which is
// the same array the :EVENT:PROJECTILE: record is built from.
private _vehicleId = -1;
if (_tempKey isNotEqualTo "" && {!isNil QGVAR(trackedProjectiles)}) then {
  private _entry = GVAR(trackedProjectiles) getOrDefault [_tempKey, []];
  if (_entry isNotEqualTo []) then {
    private _data = _entry select 0;
    if (_firerId isEqualTo -1) then {_firerId = _data select 2};
    _vehicleId = _data select 3;
  };
};

// Side is read from the firer rather than sent, so it cannot disagree with the
// entity record. An unattributed blast (Zeus, script, editor mine) has none.
private _side = "";
if (_firerId > -1) then {
  private _firer = objNull;
  if (!isNil QGVAR(trackedUnits)) then {
    _firer = GVAR(trackedUnits) getOrDefault [_firerId, objNull];
  };
  if (!isNull _firer) then {
    _side = str (side group _firer);
  } else {
    // A vehicle OCAP knows only as a vehicle record has no group, so its own
    // side is the answer there.
    if (!isNil QGVAR(trackedVehicles)) then {
      private _entry = GVAR(trackedVehicles) getOrDefault [_firerId, []];
      if (_entry isNotEqualTo [] && {!isNull (_entry select 0)}) then {
        _side = str (side (_entry select 0));
      };
    };
  };
};

[":EVENT:GENERAL:", [
  _frame max 0,
  "explosion",
  [createHashMapFromArray [
    ["x", round (_coords select 0)],
    ["y", round (_coords select 1)],
    ["ammo", _ammo],
    ["name", _name],
    // One decimal, not a whole metre. Rounding to an integer turns any blast
    // under half a metre into radius 0, and a reader cannot draw a zero-radius
    // circle -- the web client drops those events entirely. That is unreachable
    // at the default minimum radius of 2, but it is reachable the moment someone
    // lowers the setting, and silently discarding what the recorder went to the
    // trouble of writing is the worst way to find out. Still a plain JSON
    // number, so recordings written before this read back the same.
    ["radius", (round (_radius * 10)) / 10],
    ["power", round _damage],
    ["firerId", _firerId],
    ["vehicleId", _vehicleId],
    ["side", _side],
    ["source", _source]
  ]] call FUNC(encodeJSON)
]] call EFUNC(extension,sendData);

if (GVARMAIN(isDebug)) then {
  OCAPEXTLOG(ARR3("EXPLOSION",_ammo,_radius));
};
