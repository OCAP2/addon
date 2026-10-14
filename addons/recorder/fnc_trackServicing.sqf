/* ----------------------------------------------------------------------------
FILE: fnc_trackServicing.sqf

FUNCTION: OCAP_recorder_fnc_trackServicing

Description:
  Records vehicles being repaired, refuelled and rearmed as additive
  `serviceEvent` general events, so a recording shows the logistics side of a
  mission instead of a damaged truck silently becoming a healthy one.

  Runs entirely on the server.

  Repair and refuel are detected by watching state, not by hooking a mod.
  `damage` and `fuel` are engine properties synchronised to every machine, so
  the server sees them change no matter who did the work -- ACE repair, ACE
  refuel, a vanilla repair truck, a Zeus heal, or a mission script. Hooking ACE
  instead would record only ACE: `ace_repair` publishes its result with
  `ace_repair_setVehicleHitPointDamage`, a targetEvent that fires where the
  *vehicle* is local, which on a dedicated server is not reliably the server,
  and `ace_refuel` raises no completion event at all.

  Rearm is the exception and is taken from ACE, because ammo state is not
  readable for a remote turret the way fuel and damage are.
  `ace_rearm_rearmSuccessEH` is a serverEvent ACE already sends for every
  client-side rearm, and `ace_rearm_rearmSuccessLocalEH` covers the case where
  the server itself finished the progress bar. Both carry the same arguments, so
  a short dedupe window keeps a vehicle that is local to the server -- which
  receives both -- from being recorded twice.

  Servicing is gradual: ACE refuel adds fuel continuously and a repair walks one
  hit point at a time. Sampling would therefore emit one event per tick for the
  whole minute a refuel takes. Instead each vehicle+kind opens a *session* on the
  first improvement, extends it while the improvement continues, and writes one
  event when it stops, spanning the whole job. `from` and `to` are that span.

  Attribution is by proximity, deliberately: nothing in the engine says who
  repaired a vehicle. The nearest unit outside the vehicle within
  SERVICE_ATTRIBUTION_RANGE metres when the session opens is credited, and an
  unattributed session (Zeus, script) is recorded with unitId -1 rather than
  dropped -- the fuel still went in. ACE rearm carries its own engineer and does
  not guess.

  Only overall `damage` is watched, not individual hit points. A wheel repaired
  on an otherwise healthy truck can leave overall damage unchanged and is
  therefore not recorded; that is a deliberate trade against reading
  getAllHitPointsDamage for every vehicle on every tick.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(trackServicing);

Public:
  No

Author:
  OCAP Improved
---------------------------------------------------------------------------- */
#include "script_component.hpp"

#define SERVICE_ATTRIBUTION_RANGE 20
// Ignore engine jitter and the sub-percent trickle a running engine burns back.
#define SERVICE_MIN_STEP 0.01
// A session is written out once nothing has improved for this long.
#define SERVICE_IDLE_SECONDS 8
// A rearm reported through both ACE paths inside this window is one rearm.
#define SERVICE_REARM_DEDUPE 3

if (!isServer) exitWith {};
if (!(missionNamespace getVariable [QEGVAR(settings,trackServicing), true])) exitWith {
  LOG("SERVICING: disabled by setting");
};
if (!isNil QGVAR(servicingPFH)) exitWith {};

// VARIABLE: OCAP_recorder_serviceBaseline
// Vehicle OCAP id -> [lastFuel, lastDamage]. The value the next sample is
// compared against, and the value a new session starts from.
GVAR(serviceBaseline) = createHashMap;

// VARIABLE: OCAP_recorder_serviceSessions
// "<vehicleId>:<kind>" -> [vehicle, vehicleId, kind, unitId, unitName, side,
// from, to, lastChangeTime]. Only jobs currently in progress live here, so it is
// empty most of the time.
GVAR(serviceSessions) = createHashMap;

// VARIABLE: OCAP_recorder_serviceRearmSeen
// Rearm dedupe keys -> mission time of the last accepted report.
GVAR(serviceRearmSeen) = createHashMap;


/*
  Function: OCAP_recorder_serviceAttribution (local)
  Credits the nearest unit standing outside the vehicle. Crew are excluded: a
  driver sitting in a truck being refuelled by someone else must not take the
  credit. Returns [unitId, unitName, side], or [-1, "", ""] when nobody is close.
*/
GVAR(serviceAttribution) = {
  params ["_vehicle"];

  private _crew = crew _vehicle;
  private _best = objNull;
  private _bestDistance = SERVICE_ATTRIBUTION_RANGE;

  {
    if (_x in _crew) then {continue};
    if (!alive _x) then {continue};
    if ((_x getVariable [QGVARMAIN(id), -1]) isEqualTo -1) then {continue};
    private _distance = _x distance _vehicle;
    if (_distance < _bestDistance) then {
      _bestDistance = _distance;
      _best = _x;
    };
  } forEach (_vehicle nearEntities ["CAManBase", SERVICE_ATTRIBUTION_RANGE]);

  if (isNull _best) exitWith {[-1, "", ""]};
  [_best getVariable [QGVARMAIN(id), -1], name _best, str (side group _best)]
};


/*
  Function: OCAP_recorder_submitServiceEvent (local)
  Writes one serviceEvent. The vehicle display name is resolved with getTextRaw
  and cached on the object, because getText would write the recording server's
  locale into a file read in eight languages (see AGENTS.md).
*/
GVAR(submitServiceEvent) = {
  params ["_kind", "_vehicle", "_vehicleId", "_unitId", "_unitName", "_side", "_from", "_to", ["_extra", []]];

  if (!SHOULDSAVEEVENTS) exitWith {};
  if (!EGVAR(extension,sessionReady)) exitWith {};
  if (_vehicleId isEqualTo -1) exitWith {};

  private _pos = [0, 0, 0];
  private _vehicleName = "";
  if (!isNull _vehicle) then {
    _pos = getPosASL _vehicle;
    _vehicleName = _vehicle getVariable [QGVAR(serviceDisplayName), ""];
    if (_vehicleName isEqualTo "") then {
      _vehicleName = getTextRaw (configOf _vehicle >> "displayName");
      if (_vehicleName isEqualTo "" || {(_vehicleName select [0, 1]) isEqualTo "$"}) then {
        _vehicleName = typeOf _vehicle;
      };
      _vehicle setVariable [QGVAR(serviceDisplayName), _vehicleName];
    };
  };

  private _payload = createHashMapFromArray [
    ["kind", _kind],
    ["vehicleId", _vehicleId],
    ["vehicleName", _vehicleName],
    ["unitId", _unitId],
    ["unitName", _unitName],
    ["side", _side],
    ["x", round (_pos select 0)],
    ["y", round (_pos select 1)],
    ["from", (round (_from * 100)) / 100],
    ["to", (round (_to * 100)) / 100]
  ];

  // Rearm adds what was loaded; repair and refuel are fully described by from/to.
  {
    _payload set [_x select 0, _x select 1];
  } forEach _extra;

  [":EVENT:GENERAL:", [
    GVAR(captureFrameNo) max 0,
    "serviceEvent",
    [_payload] call FUNC(encodeJSON)
  ]] call EFUNC(extension,sendData);

  if (GVARMAIN(isDebug)) then {
    OCAPEXTLOG(ARR4("SERVICING",_kind,_vehicleId,_unitId));
  };
};


/*
  Function: OCAP_recorder_closeServiceSession (local)
  Emits a finished session and forgets it. A session whose whole span ended up
  below the step threshold is dropped, which happens when a single sample
  crossed the threshold and the next one reversed it.
*/
GVAR(closeServiceSession) = {
  params ["_key"];

  private _session = GVAR(serviceSessions) getOrDefault [_key, []];
  if (_session isEqualTo []) exitWith {};
  GVAR(serviceSessions) deleteAt _key;

  _session params ["_vehicle", "_vehicleId", "_kind", "_unitId", "_unitName", "_side", "_from", "_to"];
  if (abs (_to - _from) < SERVICE_MIN_STEP) exitWith {};

  [_kind, _vehicle, _vehicleId, _unitId, _unitName, _side, _from, _to] call GVAR(submitServiceEvent);
};


/*
  Function: OCAP_recorder_flushServiceSessions (local)
  Writes out every session still open. Called from <OCAP_recorder_fnc_stopRecording>
  before recording is switched off, so a repair still in progress at mission end
  is not lost.
*/
GVAR(flushServiceSessions) = {
  {
    [_x] call GVAR(closeServiceSession);
  } forEach (keys GVAR(serviceSessions));
};


/*
  Function: OCAP_recorder_noteServiceProgress (local)
  Opens or extends the session for one vehicle and kind.
*/
GVAR(noteServiceProgress) = {
  params ["_vehicle", "_vehicleId", "_kind", "_from", "_to", "_now"];

  private _key = format ["%1:%2", _vehicleId, _kind];
  private _session = GVAR(serviceSessions) getOrDefault [_key, []];

  if (_session isEqualTo []) exitWith {
    ([_vehicle] call GVAR(serviceAttribution)) params ["_unitId", "_unitName", "_side"];
    GVAR(serviceSessions) set [_key, [_vehicle, _vehicleId, _kind, _unitId, _unitName, _side, _from, _to, _now]];
  };

  // Keep the first attribution: the engineer who started the job is the one who
  // did it, even if they step away before it finishes.
  _session set [7, _to];
  _session set [8, _now];
};


// The sampler. Walks vehicles rather than GVAR(trackedVehicles), because that
// hashmap only gains an entry once a vehicle's state has changed at least once
// -- a truck parked all mission and then refuelled would never appear in it.
GVAR(servicingPFH) = [{
  if (!SHOULDSAVEEVENTS) exitWith {};

  private _now = CBA_missionTime;

  {
    private _vehicle = _x;
    private _vehicleId = _vehicle getVariable [QGVARMAIN(id), -1];
    if (_vehicleId isEqualTo -1) then {continue};
    if (_vehicle getVariable [QGVARMAIN(exclude), false]) then {continue};

    private _fuel = fuel _vehicle;
    private _damage = damage _vehicle;
    private _baseline = GVAR(serviceBaseline) getOrDefault [_vehicleId, []];

    if (_baseline isEqualTo []) then {
      GVAR(serviceBaseline) set [_vehicleId, [_fuel, _damage]];
      continue;
    };

    _baseline params ["_lastFuel", "_lastDamage"];

    // Nearly every vehicle is unchanged on nearly every pass. Skip it before any
    // further work or allocation; the baseline it would rewrite is identical.
    if (_fuel isEqualTo _lastFuel && {_damage isEqualTo _lastDamage}) then {continue};

    if (alive _vehicle) then {
      if (_fuel - _lastFuel >= SERVICE_MIN_STEP) then {
        [_vehicle, _vehicleId, "refuel", _lastFuel, _fuel, _now] call GVAR(noteServiceProgress);
      };
      if (_lastDamage - _damage >= SERVICE_MIN_STEP) then {
        [_vehicle, _vehicleId, "repair", _lastDamage, _damage, _now] call GVAR(noteServiceProgress);
      };
    };

    _baseline set [0, _fuel];
    _baseline set [1, _damage];
  } forEach vehicles;

  // Close out anything that has stopped progressing, and anything whose vehicle
  // is gone -- a destroyed or deleted vehicle still deserves the work already
  // done to be recorded.
  {
    private _session = GVAR(serviceSessions) getOrDefault [_x, []];
    if (_session isEqualTo []) then {continue};
    if (isNull (_session select 0) || {_now - (_session select 8) >= SERVICE_IDLE_SECONDS}) then {
      [_x] call GVAR(closeServiceSession);
    };
  } forEach (keys GVAR(serviceSessions));
}, missionNamespace getVariable [QEGVAR(settings,serviceSampleInterval), 5]] call CBA_fnc_addPerFrameHandler;


// ACE rearm. Both handlers receive identical arguments; whichever arrives first
// wins and the other is swallowed by the dedupe window.
if (isClass (configFile >> "CfgPatches" >> "ace_rearm")) then {
  GVAR(handleAceRearm) = {
    params ["_vehicle", "_unit", "_turretPath", "_numMagazines", "_magazineClass", "_numRounds"];

    if (!SHOULDSAVEEVENTS) exitWith {};
    if (isNull _vehicle) exitWith {};

    private _vehicleId = _vehicle getVariable [QGVARMAIN(id), -1];
    if (_vehicleId isEqualTo -1) exitWith {};

    private _now = CBA_missionTime;
    private _key = format ["%1:%2:%3", _vehicleId, _magazineClass, _turretPath];
    if (_now - (GVAR(serviceRearmSeen) getOrDefault [_key, -1e10]) < SERVICE_REARM_DEDUPE) exitWith {};
    GVAR(serviceRearmSeen) set [_key, _now];

    private _unitId = -1;
    private _unitName = "";
    private _side = "";
    if (!isNull _unit) then {
      _unitId = _unit getVariable [QGVARMAIN(id), -1];
      _unitName = name _unit;
      _side = str (side group _unit);
    };

    private _magazineName = getTextRaw (configFile >> "CfgMagazines" >> _magazineClass >> "displayName");
    if (_magazineName isEqualTo "" || {(_magazineName select [0, 1]) isEqualTo "$"}) then {
      _magazineName = _magazineClass;
    };

    [
      "rearm", _vehicle, _vehicleId, _unitId, _unitName, _side, 0, 0,
      [
        ["magazine", _magazineClass],
        ["magazineName", _magazineName],
        ["count", _numMagazines],
        ["rounds", _numRounds]
      ]
    ] call GVAR(submitServiceEvent);
  };

  {
    [_x, {_this call GVAR(handleAceRearm)}] call CBA_fnc_addEventHandler;
  } forEach ["ace_rearm_rearmSuccessEH", "ace_rearm_rearmSuccessLocalEH"];

  LOG("SERVICING: ACE rearm listeners registered");
};

LOG("SERVICING: repair/refuel/rearm tracking initialized");
