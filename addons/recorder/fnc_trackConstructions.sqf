/* ----------------------------------------------------------------------------
FILE: fnc_trackConstructions.sqf

FUNCTION: OCAP_recorder_fnc_trackConstructions

Description:
  Records field construction: ACE3 Fortify placements as placed objects, and
  static weapons that were assembled during the mission being taken apart again.

  Runs entirely on the server.

  Fortify objects -- sandbag walls, bunkers, H-barriers, wire -- are recorded
  through the same placed-object pipeline trenches use, so each one becomes an
  oriented, labelled map icon and needs no new event type. ACE raises
  `acex_fortify_objectPlaced` as a global event and handles it server-side
  itself, so unlike the CSW and Fortify *deploy* events, which are client-local,
  this one arrives here for free with the builder attached.

  The object is created on the placing client, so its position has not
  necessarily synced when the event arrives. ACE has the same problem for its own
  map marker and solves it with a one second delay; this does the same, and reads
  the settled position afterwards.

  Static weapon *assembly* is reported by the units themselves -- see
  <OCAP_recorder_fnc_submitStaticWeapon>. What is handled here is the one case no
  event covers: ACE CSW's pickup action deletes the gun without raising anything,
  so a gun we recorded being built and which then disappears intact is reported
  as taken apart, credited to the nearest unit. A gun that was destroyed is not:
  that is already a kill event.

  Objects nobody can be credited for are not recorded. The placed-object parser
  reads the owner id as unsigned and rejects a record with -1, and a fortification
  that appeared on its own is not the player action this feature is about.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(trackConstructions);

Public:
  No

Author:
  OCAP Improved
---------------------------------------------------------------------------- */
#include "script_component.hpp"

// Let the placing client's position sync reach the server before reading it.
#define FORTIFY_SETTLE_DELAY 1
// How often the vanished-gun sweep runs, in seconds.
#define STATIC_SWEEP_INTERVAL 3
// Credit a disassembly to a unit no further than this from the gun.
#define STATIC_PICKUP_RANGE 12
// How long a unit's disassembly claim waits for a gun to disappear, in seconds.
#define STATIC_CLAIM_TTL 20

if (!isServer) exitWith {};
if (!(missionNamespace getVariable [QEGVAR(settings,trackConstructions), true])) exitWith {
  LOG("CONSTRUCTIONS: disabled by setting");
};
if (!isNil QGVAR(constructionsInitialized)) exitWith {};
GVAR(constructionsInitialized) = true;

// VARIABLE: OCAP_recorder_staticWeaponSnapshot
// OCAP id -> [class, lastPosASL, englishName] for every static weapon that
// existed at the previous sweep. Comparing it against the current set is how a
// disassembly is detected at all -- see the sweep at the bottom of this file.

/*
  VARIABLE: OCAP_recorder_fortifyIcons

  Base class -> marker icon, checked in order with isKindOf so a mission's own
  H-barrier variant still lands on the H-barrier icon. Fortify's placeable set is
  mission-defined, so there is no fixed class list to match on and anything
  unrecognised falls through to the generic icon.
*/
GVAR(fortifyIcons) = [
  ["Land_BagBunker_Base_F", "fort_bunker"],
  ["Land_BagFence_Base_F", "fort_sandbag"],
  ["Land_HBarrier_Base_F", "fort_barrier"],
  ["Land_HBarrierWall_base_F", "fort_barrier"],
  ["Land_Razorwire_F", "fort_wire"],
  ["Land_CncBarrier_F", "fort_barrier"],
  ["Land_CncWall4_F", "fort_barrier"],
  ["StaticWeapon", "fort_static"],
  ["Land_TentDome_F", "fort_tent"],
  ["Land_MedicalTent_01_base_F", "fort_tent"]
];


/*
  Function: OCAP_recorder_fortifyIconFor (local)
  Resolves the marker icon for a fortification class.
*/
GVAR(fortifyIconFor) = {
  params ["_object"];

  private _icon = "fortification";
  {
    _x params ["_base", "_candidate"];
    if (_object isKindOf _base) exitWith {_icon = _candidate};
  } forEach GVAR(fortifyIcons);

  _icon
};


/*
  Function: OCAP_recorder_submitFortification (local)
  Builds and sends the :PLACED:CREATE: record for one finished fortification.

  Indices 0-8 are the shape mines and ACE explosives already use; 9 and 10 are
  the additive direction and icon fields trenches introduced, which an older
  extension stops reading before.
*/
GVAR(submitFortification) = {
  params ["_object", "_unit"];

  if (isNull _object || {isNull _unit}) exitWith {};
  if (!SHOULDSAVEEVENTS) exitWith {};
  if (!EGVAR(extension,sessionReady)) exitWith {};

  private _ownerId = _unit getVariable [QGVARMAIN(id), -1];
  if (_ownerId isEqualTo -1) exitWith {
    if (GVARMAIN(isDebug)) then {
      OCAPEXTLOG(ARR2("CONSTRUCTIONS: skipping unattributed fortification",typeOf _object));
    };
  };

  private _class = typeOf _object;
  // Never store a localized string in a recording -- see AGENTS.md.
  private _name = getTextRaw (configFile >> "CfgVehicles" >> _class >> "displayName");
  if (_name isEqualTo "" || {(_name select [0, 1]) isEqualTo "$"}) then {_name = _class};

  private _clock = [daytime, "HH:MM"] call BIS_fnc_timeToString;
  private _label = format ["%1 - %2 - %3", _name, name _unit, _clock];

  private _placedData = [
    GVAR(captureFrameNo),                   // 0: captureFrameNo
    -1,                                     // 1: placedId (assigned by handlePlacedData)
    _class,                                 // 2: className
    _label,                                 // 3: displayName -- becomes the marker text
    (getPosASL _object) joinString ",",     // 4: position
    _ownerId,                               // 5: firerOcapId (builder)
    str (side group _unit),                 // 6: side
    "fortify",                              // 7: weapon slot, reused as a kind discriminator
    "",                                     // 8: magazineIcon -- superseded by index 10
    getDir _object,                         // 9: direction (additive)
    [_object] call GVAR(fortifyIconFor)     // 10: marker icon name (additive)
  ];

  if (GVARMAIN(isDebug)) then {
    OCAPEXTLOG(ARR3("CONSTRUCTIONS: recording fortification",_class,_label));
  };

  // handlePlacedData is registered server-side in fnc_eh_fired_server.sqf and
  // assigns the placed id there, because GVAR(nextId) only exists on the server.
  [QGVARMAIN(handlePlacedData), [_placedData, _object]] call CBA_fnc_localEvent;
};


// ACE3 Fortify. The event is global and ACE listens for it on the server too, so
// this needs no client bootstrap. Fires for every completed placement, cancelled
// ones never get here.
if (isClass (configFile >> "CfgPatches" >> "acex_fortify") ||
    {isClass (configFile >> "CfgPatches" >> "ace_fortify")}) then {
  ["acex_fortify_objectPlaced", {
    params ["_unit", "_side", "_object"];
    if (isNull _object) exitWith {};

    [{
      _this call GVAR(submitFortification);
    }, [_object, _unit], FORTIFY_SETTLE_DELAY] call CBA_fnc_waitAndExecute;
  }] call CBA_fnc_addEventHandler;

  LOG("CONSTRUCTIONS: ACE Fortify listener registered");
};


// Static weapon disassembly.
//
// Nothing reports it directly. Vanilla's WeaponDisassembled hands over the two
// bags, not the gun, and by the time it fires the gun is already deleted; ACE
// CSW's pickup action raises nothing at all. What both leave behind is the same
// observable fact -- a static weapon that existed one tick ago is gone, and was
// not destroyed. This sweep watches for exactly that, then credits it to the
// unit whose disassembly claim matches, or failing that to whoever was standing
// closest.
//
// A gun that was destroyed is left alone: that is already a kill event, and its
// wreck is not alive at the last sample.
GVAR(staticWeaponSnapshot) = createHashMap;

[{
  if (!SHOULDSAVEEVENTS) exitWith {};

  private _now = CBA_missionTime;
  private _previous = GVAR(staticWeaponSnapshot);
  private _current = createHashMap;

  // Wrecks stay in the snapshot, flagged dead. Dropping them here instead would
  // make a destroyed gun's later cleanup look exactly like a disassembly.
  {
    if !(_x isKindOf "StaticWeapon") then {continue};
    private _id = _x getVariable [QGVARMAIN(id), -1];
    if (_id isEqualTo -1) then {continue};

    private _known = _previous getOrDefault [_id, []];
    private _name = "";
    if (_known isEqualTo []) then {
      // Never store a localized string in a recording -- see AGENTS.md.
      _name = getTextRaw (configOf _x >> "displayName");
      if (_name isEqualTo "" || {(_name select [0, 1]) isEqualTo "$"}) then {_name = typeOf _x};
    } else {
      _name = _known select 2;
    };

    _current set [_id, [typeOf _x, getPosASL _x, _name, alive _x]];
  } forEach vehicles;

  // Drop claims nobody can match any more before looking for one.
  if (isNil QGVAR(staticDisassembleClaims)) then {GVAR(staticDisassembleClaims) = []};
  GVAR(staticDisassembleClaims) = GVAR(staticDisassembleClaims) select {
    _now - (_x select 4) < STATIC_CLAIM_TTL
  };

  {
    private _staticId = _x;
    if (_staticId in _current) then {continue};

    (_previous get _staticId) params ["_class", "_lastPos", "_name", ["_wasAlive", true]];

    // Destroyed, not taken apart. The kill event already covers it.
    if (!_wasAlive) then {continue};

    private _unitId = -1;
    private _unitName = "";
    private _side = "";

    // An exact claim beats a guess: the unit said it took a gun apart, and it
    // was standing next to this one when it did.
    private _claimIndex = GVAR(staticDisassembleClaims) findIf {
      ((_x select 3) distance _lastPos) < STATIC_PICKUP_RANGE
    };

    if (_claimIndex > -1) then {
      (GVAR(staticDisassembleClaims) deleteAt _claimIndex) params ["_claimId", "_claimName", "_claimSide"];
      _unitId = _claimId;
      _unitName = _claimName;
      _side = _claimSide;
    } else {
      // ACE CSW pickup, or a Zeus deletion. Credit the nearest unit, or nobody.
      private _best = objNull;
      private _bestDistance = STATIC_PICKUP_RANGE;
      {
        if (!alive _x) then {continue};
        if ((_x getVariable [QGVARMAIN(id), -1]) isEqualTo -1) then {continue};
        private _distance = _x distance _lastPos;
        if (_distance < _bestDistance) then {
          _bestDistance = _distance;
          _best = _x;
        };
      } forEach (_lastPos nearEntities ["CAManBase", STATIC_PICKUP_RANGE]);

      if (!isNull _best) then {
        _unitId = _best getVariable [QGVARMAIN(id), -1];
        _unitName = name _best;
        _side = str (side group _best);
      };
    };

    [":EVENT:GENERAL:", [
      GVAR(captureFrameNo) max 0,
      "staticWeapon",
      [createHashMapFromArray [
        ["action", "disassembled"],
        ["unitId", _unitId],
        ["unitName", _unitName],
        ["side", _side],
        ["vehicleId", _staticId],
        ["class", _class],
        ["name", _name],
        ["x", round (_lastPos select 0)],
        ["y", round (_lastPos select 1)]
      ]] call CBA_fnc_encodeJSON
    ]] call EFUNC(extension,sendData);

    if (GVARMAIN(isDebug)) then {
      OCAPEXTLOG(ARR3("STATIC WEAPON disassembled",_class,_unitId));
    };
  } forEach (keys _previous);

  GVAR(staticWeaponSnapshot) = _current;
}, STATIC_SWEEP_INTERVAL] call CBA_fnc_addPerFrameHandler;

LOG("CONSTRUCTIONS: fortification and static weapon tracking initialized");
