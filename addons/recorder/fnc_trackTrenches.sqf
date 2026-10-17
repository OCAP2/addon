/* ----------------------------------------------------------------------------
FILE: fnc_trackTrenches.sqf

FUNCTION: OCAP_recorder_fnc_trackTrenches

Description:
  Records ACE3 and GRAD Trenches through the placed-object pipeline, so each
  finished trench becomes a rotated, labelled marker in playback.

  Runs entirely on the server. Detection uses a CBA class "init" event handler
  on each concrete trench class, which fires on every machine the object exists
  on -- the server included -- regardless of where the trench was created. That
  covers every way a player can dig one:

    - ACE3 digging        (object is created on the digging client)
    - GRAD digging        (object is created on the server via spawnTrench)
    - GRAD vehicle blade  (fnc_vehicleTrenchBuild, a bare createVehicle)

  Neither mod raises a "trench finished" event, so completion is taken from the
  public "ace_trenches_progress" variable reaching 1. GRAD republishes it every
  second while digging and sets exactly 1 on completion; ACE keeps its per-tick
  value local but does publish 0 at placement and 1 on completion, so the 0->1
  edge is visible on the server either way.

  Creator attribution is mod-specific and is resolved after the object appears,
  because neither creation signal carries both the object and the digger:

    - ACE3: ace_trenches_placed / ace_trenches_finished global events, which
      stamp the digger onto the trench as it is confirmed.
    - GRAD: the public "grad_trenches_functions_diggers" array on the trench;
      element 0 is the unit that started it. GRAD writes this with a plain
      setVariable on the first dig and raises no event, so it has to be read.

  Trenches with no identifiable digger -- editor- or Zeus-placed ones -- are not
  recorded at all. The placed-object pipeline parses the owner id as an unsigned
  value (ParsePlacedObject -> parseUintFromFloat), so a -1 owner would make the
  extension reject the whole record; and a trench nobody dug is not the player
  action this feature is about. The owner is therefore stamped onto the trench
  as soon as any digger is seen, so it survives that digger disconnecting or
  handing the dig over before the trench is finished.

  Removal is deliberately not tracked -- a recorded trench stays on the map for
  the rest of the recording.

  Applied during initialization of OCAP in <OCAP_recorder_fnc_init>.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(trackTrenches);

Public:
  No

Author:
  OCAP-IMPROVED
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!isServer) exitWith {};
if (!(missionNamespace getVariable [QEGVAR(settings,trackTrenches), true])) exitWith {};

// Nothing to do without ACE trenches; GRAD requires it too, so this one check covers both.
if (!isClass (configFile >> "CfgPatches" >> "ace_trenches")) exitWith {
  LOG("TRENCHES: ace_trenches not loaded, trench tracking disabled");
};

// VARIABLE: OCAP_recorder_gradTrenches
// True when GRAD Trenches is loaded, which replaces the whole ACE dig flow and
// adds four classes of its own.
GVAR(gradTrenches) = isClass (configFile >> "CfgPatches" >> "grad_trenches_functions");

/*
  VARIABLE: OCAP_recorder_trenchTypes

  Maps each concrete trench class to [<english name>, <marker icon>].

  The English name is hardcoded rather than read from config because
  `displayName` follows the server's locale, and because GRAD overrides ACE's
  two classes with its own wording -- "ACE_envelope_small" reads
  "Envelope - Small" on ACE alone and "Trench - Small" once GRAD is loaded.
  The config value is still used as a fallback for anything unlisted.

  Only concrete classes are listed. Matching is by `typeOf`, never `isKindOf`:
  ACE's placement preview is "ACE_envelope_small_NoGeo", a scope=1 child of the
  real class created with createVehicle, so an isKindOf test would record a
  ghost trench for every aborted placement.
*/
GVAR(trenchTypes) = createHashMapFromArray [
  ["ACE_envelope_small",     [if (GVAR(gradTrenches)) then {"Trench - Small"} else {"Envelope - Small"}, "trench_small"]],
  ["ACE_envelope_big",       [if (GVAR(gradTrenches)) then {"Trench - Big"} else {"Envelope - Big"}, "trench_big"]],
  ["GRAD_envelope_short",    ["Trench - Short", "trench_short"]],
  ["GRAD_envelope_long",     ["Trench - Long", "trench_long"]],
  ["GRAD_envelope_giant",    ["Trench - Giant", "trench_giant"]],
  ["GRAD_envelope_vehicle",  ["Trench - Vehicle", "trench_vehicle"]]
];

// VARIABLE: OCAP_recorder_trackedTrenches
// Objects already sent to the extension, so no trench can be recorded twice.
GVAR(trackedTrenches) = [];

// VARIABLE: OCAP_recorder_pendingTrenches
// Trenches seen but not yet complete, watched by the progress PFH below.
GVAR(pendingTrenches) = [];


/*
  Function: OCAP_recorder_stampTrenchOwner (local)
  Caches whoever is digging a trench onto the trench itself, the first time any
  digger is visible. Called repeatedly while the trench is in progress, so the
  attribution survives that digger disconnecting, dying, or handing the dig over
  before it is finished -- GRAD empties its digger list in all three cases.
  Returns the owner unit, or objNull while nobody has claimed it.
*/
private _fnc_stampTrenchOwner = {
  params ["_trench"];

  // ACE stamps the digger through its own events (registered further down).
  private _unit = _trench getVariable [QGVARMAIN(trenchOwner), objNull];
  if (!isNull _unit) exitWith {_unit};

  // GRAD writes its digger list with a plain public setVariable and no event,
  // so it has to be read rather than listened for.
  private _diggers = _trench getVariable ["grad_trenches_functions_diggers", []];
  if (_diggers isEqualType [] && {count _diggers > 0}) then {
    private _first = _diggers select 0;
    if (_first isEqualType objNull && {!isNull _first}) then {
      _unit = _first;
      _trench setVariable [QGVARMAIN(trenchOwner), _unit];
    };
  };

  _unit
};

GVAR(stampTrenchOwner) = _fnc_stampTrenchOwner;


/*
  Function: OCAP_recorder_submitTrench (local)
  Builds and sends the :PLACED:CREATE: record for a completed trench.

  Indices 0-8 are byte-for-byte the shape mines and ACE explosives already use.
  Indices 9 and 10 are additive and optional: an older extension stops reading
  after index 8 (ParsePlacedObject guards with `len(data) < 9` and reads by
  index), and an older recording simply has no direction or icon.
*/
private _fnc_submitTrench = {
  params ["_trench"];

  if (isNull _trench) exitWith {};
  if (_trench in GVAR(trackedTrenches)) exitWith {};
  if (!SHOULDSAVEEVENTS) exitWith {};

  private _class = typeOf _trench;
  private _info = GVAR(trenchTypes) getOrDefault [_class, []];
  private _name = "";
  private _icon = "trench";
  if (_info isEqualTo []) then {
    // Unlisted class -- fall back to the server's locale and the generic icon.
    _name = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
    if (_name isEqualTo "") then {_name = _class};
  } else {
    _info params ["_localName", "_localIcon"];
    _name = _localName;
    _icon = _localIcon;
  };

  private _owner = [_trench] call GVAR(stampTrenchOwner);
  private _ownerId = -1;
  if (!isNull _owner) then {_ownerId = _owner getVariable [QGVARMAIN(id), -1]};

  // No digger, or a digger OCAP never registered as an entity. The placed-object
  // parser reads the owner as unsigned and would reject the whole record, so
  // drop it here instead of sending something the extension will refuse.
  if (_ownerId isEqualTo -1) exitWith {
    if (GVARMAIN(isDebug)) then {
      OCAPEXTLOG(ARR2("TRENCHES: skipping unattributed trench",_class));
    };
  };

  // Label shown next to the marker: type, who dug it, and the mission clock at
  // the moment it was finished. The marker also carries its own start frame, so
  // the timestamp here is purely for readability.
  private _clock = [daytime, "HH:MM"] call BIS_fnc_timeToString;
  private _label = format ["%1 - %2 - %3", _name, name _owner, _clock];

  private _side = str (side group _owner);

  private _placedData = [
    GVAR(captureFrameNo),                   // 0: captureFrameNo
    -1,                                     // 1: placedId (assigned by handlePlacedData)
    _class,                                 // 2: className
    _label,                                 // 3: displayName -- becomes the marker text
    (getPosASL _trench) joinString ",",     // 4: position
    _ownerId,                               // 5: firerOcapId (digger)
    _side,                                  // 6: side
    "trench",                               // 7: weapon slot, reused as a kind discriminator
    "",                                     // 8: magazineIcon -- superseded by index 10
    getDir _trench,                         // 9: direction (additive)
    _icon                                   // 10: marker icon name (additive)
  ];

  GVAR(trackedTrenches) pushBackUnique _trench;

  if (GVARMAIN(isDebug)) then {
    OCAPEXTLOG(ARR3("TRENCHES: recording",_class,_label));
  };

  // The placed-object pipeline also polls its objects for a locality change so it
  // can re-arm mine handlers on the server, and "Explode" is a projectile-only
  // event: on a trench it throws "Unknown enum value" and aborts that poll for
  // every mine after it. A trench never explodes and its removal is deliberately
  // not tracked (see above), so mark it as already handled.
  _trench setVariable [QGVARMAIN(serverPlacedEHs), true];

  // handlePlacedData is registered server-side in fnc_eh_fired_server.sqf and
  // assigns the placed id there, because GVAR(nextId) only exists on the server.
  [QGVARMAIN(handlePlacedData), [_placedData, _trench]] call CBA_fnc_localEvent;
};

GVAR(submitTrench) = _fnc_submitTrench;


/*
  Function: OCAP_recorder_watchTrench (local)
  Queues a newly seen trench for the completion watcher, ignoring duplicates and
  anything already recorded.
*/
private _fnc_watchTrench = {
  params ["_trench"];

  if (isNull _trench) exitWith {};
  if (!(typeOf _trench in GVAR(trenchTypes))) exitWith {};
  if (_trench in GVAR(trackedTrenches)) exitWith {};
  if (_trench in GVAR(pendingTrenches)) exitWith {};

  GVAR(pendingTrenches) pushBack _trench;

  if (GVARMAIN(isDebug)) then {
    OCAPEXTLOG(ARR2("TRENCHES: watching",typeOf _trench));
  };
};

GVAR(watchTrench) = _fnc_watchTrench;


// Class init handlers -- the universal "a trench object now exists" signal.
// Fires on every machine the object exists on, the server included, whichever
// machine actually created it. GRAD relies on the same mechanism in its own
// fnc_initTrench.sqf, which has an isServer branch.
{
  [
    _x,
    "init",
    {(_this select 0) call GVAR(watchTrench)},
    false,  // do not include inherited classes -- keeps the _NoGeo previews out
    [],
    false   // no retroactive sweep: pre-placed trenches have no digger to credit
  ] call CBA_fnc_addClassEventHandler;
} forEach (keys GVAR(trenchTypes));


// ACE3 creation events. Both are global events, so they reach the server even
// though the trench object itself is created on the digging client. GRAD
// deletes ACE's self-actions and these never fire when it is loaded, which is
// why the GRAD digger list is read instead.
{
  [_x, {
    params ["_unit", "_trench"];
    if (isNull _trench) exitWith {};
    _trench setVariable [QGVARMAIN(trenchOwner), _unit];
    [_trench] call GVAR(watchTrench);
  }] call CBA_fnc_addEventHandler;
} forEach ["ace_trenches_placed", "ace_trenches_finished"];


/*
  Completion watcher.

  Neither mod raises a completion event. GRAD's closest candidate,
  grad_trenches_functions_handleTrenchState, fires both when a dig finishes and
  whenever the digger count drops to zero, so it cannot distinguish "built" from
  "abandoned". It also fires before the progress value is published, so reading
  progress from inside it races the network sync.

  Polling the public progress avoids all of that and is the one mechanism that
  works for ACE, GRAD hand-digging, GRAD vehicle digging and pre-placed trenches
  alike. The list holds only trenches still being dug, so it is empty most of
  the time.
*/
[{
  if (GVAR(pendingTrenches) isEqualTo []) exitWith {};
  if (!SHOULDSAVEEVENTS) exitWith {};

  private _stillPending = [];

  {
    private _trench = _x;

    // Gone before it was ever finished -- drop it, nothing was recorded.
    if (isNull _trench) then {continue};

    // Remember the digger as soon as one is visible. GRAD clears its digger
    // list when a dig is handed over, paused or abandoned, so waiting until the
    // trench is finished would lose the attribution.
    [_trench] call GVAR(stampTrenchOwner);

    if ((_trench getVariable ["ace_trenches_progress", 0]) >= 1) then {
      [_trench] call GVAR(submitTrench);
    } else {
      _stillPending pushBack _trench;
    };
  } forEach GVAR(pendingTrenches);

  GVAR(pendingTrenches) = _stillPending;
}, 2] call CBA_fnc_addPerFrameHandler;

LOG("TRENCHES: trench tracking initialized");
