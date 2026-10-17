/* ----------------------------------------------------------------------------
FILE: fnc_installPlayerTrackingClients.sqf

FUNCTION: OCAP_recorder_fnc_installPlayerTrackingClients

Description:
  Ships the whole player-detail sampler to every client, including late joiners.

  OCAP is a server-only addon, so clients have neither our CfgFunctions nor the
  extension. Everything a client needs is therefore sent as one code block whose
  helpers live in global variables named OCAP_recorder_client_*. Clients sample
  only their own local unit and hand the result back to the server, which is the
  trust boundary (see <OCAP_recorder_fnc_submitPlayerSnapshot>).

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(installPlayerTrackingClients);

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

// Clients never load this PBO, so they never register our CBA settings. The
// server therefore publishes the current values under the same variable names
// the sampler already reads. Without this, a dedicated-server interval of 30 s
// is silently ignored and every client falls back to the hardcoded default.
if (isNil QGVAR(playerTrackingSettingNames)) then {
  GVAR(playerTrackingSettingNames) = [
    QEGVAR(settings,trackPlayerInventory),
    QEGVAR(settings,playerInventoryInterval),
    QEGVAR(settings,trackPlayerInventoryOnDeath),
    QEGVAR(settings,trackPlayerTraits),
    QEGVAR(settings,trackPlayerMedical),
    QEGVAR(settings,playerMedicalInterval),
    QEGVAR(settings,playerMedicalCriticalInterval),
    QEGVAR(settings,trackPlayerStamina),
    QEGVAR(settings,playerStaminaInterval),
    QEGVAR(settings,trackPlayerRadio),
    QEGVAR(settings,playerRadioInterval),
    QEGVAR(settings,trackPlayerSnapshotDiffs),
    QEGVAR(settings,radioShortRangeMeters),
    QEGVAR(settings,radioLongRangeMeters),
    QEGVAR(settings,trackZeus),
    QEGVAR(settings,zeusCameraInterval),
    QEGVAR(settings,trackZeusPings),
    QEGVAR(settings,trackZeusModules),
    QEGVAR(settings,trackConstructions)
  ];

  GVAR(publishPlayerTrackingSettings) = {
    {
      missionNamespace setVariable [_x, missionNamespace getVariable _x, true];
    } forEach GVAR(playerTrackingSettingNames);
  };

  ["CBA_SettingChanged", {
    params ["_setting"];
    if (_setting in GVAR(playerTrackingSettingNames)) then {
      missionNamespace setVariable [_setting, missionNamespace getVariable _setting, true];
    };
  }] call CBA_fnc_addEventHandler;
};

call GVAR(publishPlayerTrackingSettings);

{
  if (!hasInterface || {!isNil "OCAP_recorder_client_playerTrackingPFH"}) exitWith {};

  OCAP_recorder_client_hasAceMedical = isClass (configFile >> "CfgPatches" >> "ace_medical_engine");
  OCAP_recorder_client_hasKatMedical = isClass (configFile >> "CfgPatches" >> "kat_main");
  OCAP_recorder_client_hasAceFatigue = isClass (configFile >> "CfgPatches" >> "ace_advanced_fatigue");
  OCAP_recorder_client_hasTfar = isClass (configFile >> "CfgPatches" >> "tfar_core");
  OCAP_recorder_client_hasAcre = isClass (configFile >> "CfgPatches" >> "acre_api");
  // The three ACE components that layer their own training level on top of an
  // engine trait. Each is optional on its own, so they are checked one by one.
  OCAP_recorder_client_hasAceMedicalTreatment = isClass (configFile >> "CfgPatches" >> "ace_medical_treatment");
  OCAP_recorder_client_hasAceRepair = isClass (configFile >> "CfgPatches" >> "ace_repair");
  OCAP_recorder_client_hasAceExplosives = isClass (configFile >> "CfgPatches" >> "ace_explosives");

  // getAllUnitTraits reports the engine traits with its own capitalisation
  // ("Medic", "UavHacker", "CamouflageCoef"), so they are matched lowercased and
  // written under one fixed key each. Anything else is a custom trait a mission
  // or mod added with setUnitTrait and is kept under its own name.
  OCAP_recorder_client_traitKeys = createHashMapFromArray [
    ["medic", "medic"],
    ["engineer", "engineer"],
    ["explosivespecialist", "explosiveSpecialist"],
    ["uavhacker", "uavHacker"],
    ["camouflagecoef", "camouflageCoef"],
    ["audiblecoef", "audibleCoef"],
    ["loadcoef", "loadCoef"]
  ];

  // Everything that decides what a unit is allowed to do: the engine traits and,
  // where ACE is loaded, the graded training ACE reads instead of them. The ACE
  // values are read exactly the way ace_medical_treatment_fnc_isMedic,
  // ace_repair_fnc_isEngineer and ace_common_fnc_isEOD read them, including the
  // fall-through to the engine trait when the ACE variable was never set, so the
  // recording shows the level the mod actually acted on.
  //
  // Traits ride inside the inventory snapshot: they are assigned with the
  // loadout, change about as often, and the server's diff then carries them only
  // when they change.
  OCAP_recorder_client_buildTraits = {
    params ["_unit"];

    private _traits = createHashMap;
    private _custom = createHashMap;
    {
      _x params [["_name", "", [""]], "_value"];
      if (_name isEqualTo "" || {isNil "_value"}) then {continue};
      // A custom trait can hold anything; only what JSON can carry is recorded.
      if (!(_value isEqualType "" || {_value isEqualType 0} || {_value isEqualType false})) then {continue};
      private _key = OCAP_recorder_client_traitKeys get (toLower _name);
      if (isNil "_key") then {
        _custom set [_name, _value];
      } else {
        _traits set [_key, _value];
      };
    } forEach getAllUnitTraits _unit;
    if (count _custom > 0) then {_traits set ["custom", _custom]};

    private _ace = createHashMap;
    if (OCAP_recorder_client_hasAceMedicalTreatment) then {
      // 0 none, 1 medic, 2 doctor.
      private _level = _unit getVariable ["ace_medical_medicClass", parseNumber (_unit getUnitTrait "medic")];
      if (_level isEqualType false) then {_level = parseNumber _level};
      if (!(_level isEqualType 0)) then {_level = 0};
      _ace set ["medic", _level];
    };
    if (OCAP_recorder_client_hasAceRepair) then {
      // 0 none, 1 engineer, 2 advanced engineer. ACE writes `true` for 1.
      private _level = _unit getVariable ["ACE_IsEngineer", _unit getUnitTrait "engineer"];
      if (_level isEqualType false) then {_level = parseNumber _level};
      if (!(_level isEqualType 0)) then {_level = 0};
      _ace set ["engineer", _level];
    };
    if (OCAP_recorder_client_hasAceExplosives) then {
      _ace set ["eod", (_unit getVariable ["ACE_isEOD", _unit getUnitTrait "explosiveSpecialist"]) in [1, true]];
    };
    if (count _ace > 0) then {_traits set ["ace", _ace]};

    _traits
  };

  // ACE body part order. Every per-part array in ACE and KAT is indexed by this.
  OCAP_recorder_client_bodyParts = ["head", "body", "leftarm", "rightarm", "leftleg", "rightleg"];

  // Throwables are exactly the magazines the engine's Throw weapon can fire, which
  // is how ACE's own arsenal separates grenades from ammunition.
  OCAP_recorder_client_throwableClasses = [];
  {
    {
      OCAP_recorder_client_throwableClasses pushBackUnique toLower _x;
    } forEach getArray (configFile >> "CfgWeapons" >> "Throw" >> _x >> "magazines");
  } forEach getArray (configFile >> "CfgWeapons" >> "Throw" >> "muzzles");

  // The web UI used to guess an item's category by substring-matching the `.paa`
  // icon path the snapshot carried, which cost megabytes per recording for a
  // string no browser can load. The category is resolved here from config instead
  // and travels as a short label. "items" is the default and is left off the wire.
  OCAP_recorder_client_itemCategoryCache = createHashMap;
  OCAP_recorder_client_getItemCategory = {
    params [["_className", "", [""]]];
    if (_className isEqualTo "") exitWith {"items"};

    private _cached = OCAP_recorder_client_itemCategoryCache get _className;
    if (!isNil "_cached") exitWith {_cached};

    // ACE and KAM both flag every medical item with ACE_isMedicalItem, and ACE
    // sets it on the two vanilla ones as well. Without ACE, name those directly.
    private _category = "items";
    if (_className in ["FirstAidKit", "Medikit"]) then {_category = "medical"};
    {
      private _config = configFile >> _x >> _className;
      if (isClass _config && {getNumber (_config >> "ACE_isMedicalItem") == 1}) exitWith {
        _category = "medical";
      };
    } forEach ["CfgWeapons", "CfgMagazines"];

    if (_category isEqualTo "items") then {
      switch (true) do {
        case (toLower _className in OCAP_recorder_client_throwableClasses): {_category = "grenades"};
        case (isClass (configFile >> "CfgMagazines" >> _className)): {_category = "magazines"};
      };
    };

    OCAP_recorder_client_itemCategoryCache set [_className, _category];
    _category
  };

  // An item's display name is worth recording, but `getText` resolves a
  // stringtable reference in the *recording server's* language, which froze Czech
  // item names into recordings the web UI then showed to viewers in every locale.
  //
  // `getTextRaw` hands back what the config actually holds. A mod author who
  // typed the name in is giving us English, so that is used as-is. A "$STR_..."
  // reference cannot be read in another language from SQF, so the name is derived
  // from the class instead, which is English by construction. Either way nothing
  // localized reaches the recording.
  //
  // Keep the derivation in step with ui/src/data/gearDisplayName.ts and
  // python/convert_recording_gear.py, which derive the same label.
  OCAP_recorder_client_displayNamePrefixes = [
    "uk3cb_baf_", "rhsgref_", "rhsusf_", "rhssaf_", "immersion_",
    "uk3cb_", "acex_", "rksl_", "acre_", "tfar_", "ace_", "kat_", "cba_",
    "rhs_", "cup_", "tfr_"
  ];
  OCAP_recorder_client_displayNameCache = createHashMap;

  // The label an item falls back to when its config name is a stringtable
  // reference: the class, cleaned up. Always English, because a class always is.
  OCAP_recorder_client_deriveNameFromClass = {
    params [["_className", "", [""]]];
    if (_className isEqualTo "") exitWith {""};

    // TFAR clones each carried handheld into a per-instance class holding its
    // channel state (TFAR_anprc152_54); the prototype is the name worth showing.
    private _base = _className;
    if (_base regexMatch "(?i)(tfar|tf)_.+_\d+") then {
      _base = _base regexReplace ["_\d+$", ""];
    };

    private _lower = toLower _base;
    {
      if ((_lower find _x) == 0 && {count _base > count _x}) exitWith {
        _base = _base select [count _x];
      };
    } forEach OCAP_recorder_client_displayNamePrefixes;

    // "ItemMap", "ItemGPS": the Item prefix is engine bookkeeping, not a name.
    // Code-point check, not regex: Arma regexMatch is case-insensitive by default.
    private _itemCodes = toArray _base;
    if (
      count _itemCodes > 4 &&
      {(_itemCodes select 0) == 73} &&
      {(_itemCodes select 1) == 116} &&
      {(_itemCodes select 2) == 101} &&
      {(_itemCodes select 3) == 109} &&
      {(_itemCodes select 4) >= 65 && (_itemCodes select 4) <= 90}
    ) then {
      _base = _base select [4];
    };

    // Split on separators and at every lowercase-to-uppercase step, but never
    // between a digit and a letter, so L85A2 stays a single word.
    //
    // Use toArray code points, not regexMatch. Arma regex is case-insensitive
    // unless (?-i) is set, so [A-Z] and [a-z] both match every letter and
    // "CableTie" was recorded as "C A B L E T I E".
    private _words = [];
    private _word = "";
    private _lastCode = 0;
    {
      if (_x == 32 || {_x == 45} || {_x == 95}) then {
        if (_word isNotEqualTo "") then {_words pushBack _word; _word = ""};
        _lastCode = 0;
      } else {
        if (_word isNotEqualTo "" && {_x >= 65 && _x <= 90} && {_lastCode >= 97 && _lastCode <= 122}) then {
          _words pushBack _word;
          _word = "";
        };
        _word = _word + toString [_x];
        _lastCode = _x;
      };
    } forEach toArray _base;
    if (_word isNotEqualTo "") then {_words pushBack _word};

    private _name = (_words apply {
      // A word the mod author already capitalised is left exactly as written.
      if (_x isNotEqualTo toLower _x) then {
        _x
      } else {
        // anprc152 -> ANPRC152: a letter run followed by a digit run is a designator.
        if (_x regexMatch "[A-Za-z]{2,6}\d{2,4}") then {
          toUpper _x
        } else {
          (toUpper (_x select [0, 1])) + (_x select [1])
        };
      };
    }) joinString " ";

    if (_name isEqualTo "") then {_name = _className};
    _name
  };

  // The English display name for an item. Every gear entry gets one, so the
  // recording carries names rather than leaving a reader to work them out.
  //
  // `getText` was the problem: it resolves a stringtable reference in the
  // *recording server's* language, which is how Czech item names reached viewers
  // in eight locales. `getTextRaw` returns what the config actually holds, and
  // that answers one of two ways:
  //
  //   - a literal, which is the text the mod author typed and so is English. On a
  //     real mission take this covers about 95% of the classes a player carries:
  //     "5.56mm 30rnd Tracer Mag", "40mm HE Grenade Round (L123)".
  //   - a "$STR_..." reference, which SQF can only read in the language the game
  //     is running. There is no way to ask for English, so the name is built from
  //     the class instead, which is English by construction: "ACE_elasticBandage"
  //     becomes "Elastic Bandage" and "ItemMap" becomes "Map".
  //
  // Either way the recording only ever holds English.
  OCAP_recorder_client_gearDisplayName = {
    params [["_className", "", [""]]];
    if (_className isEqualTo "") exitWith {""};

    private _cached = OCAP_recorder_client_displayNameCache get _className;
    if (!isNil "_cached") exitWith {_cached};

    private _raw = "";
    {
      private _config = configFile >> _x >> _className;
      if (isClass _config) exitWith {
        _raw = getTextRaw (_config >> "displayName");
      };
    } forEach ["CfgWeapons", "CfgMagazines", "CfgVehicles", "CfgGlasses"];

    // getTextRaw hands back an array for a config entry written as one.
    if (_raw isEqualType []) then {_raw = _raw param [0, ""]};
    if (!(_raw isEqualType "")) then {_raw = ""};
    _raw = trim _raw;

    private _name = if (_raw isEqualTo "" || {(_raw select [0, 1]) isEqualTo "$"}) then {
      [_className] call OCAP_recorder_client_deriveNameFromClass
    } else {
      _raw
    };

    OCAP_recorder_client_displayNameCache set [_className, _name];
    _name
  };

  // Sets "name" on a gear entry. Empty slots have no class and so get no name.
  OCAP_recorder_client_setDisplayName = {
    params ["_entry", ["_className", "", [""]]];
    private _name = [_className] call OCAP_recorder_client_gearDisplayName;
    if (_name isNotEqualTo "") then {_entry set ["name", _name]};
    _entry
  };

  OCAP_recorder_client_buildInventorySnapshot = {
    params ["_unit", "_reason"];

    // The category only reaches the UI for the lists it groups: container cargo
    // and magazines. Weapons, attachments and assigned items get their own
    // sections, so paying for a category there would be waste.
    private _describeItems = {
      params ["_items", ["_withCategory", false]];

      // One counting pass, in first-seen order -- the order arrayIntersect
      // gives. Counting with `{...} count _items` once per class re-walked the
      // whole container for every distinct item in it.
      private _counts = createHashMap;
      private _order = [];
      {
        private _seen = _counts getOrDefault [_x, 0];
        if (_seen == 0) then {_order pushBack _x};
        _counts set [_x, _seen + 1];
      } forEach _items;

      _order apply {
        private _entry = [createHashMapFromArray [
          ["class", _x],
          ["count", _counts get _x]
        ], _x] call OCAP_recorder_client_setDisplayName;
        if (_withCategory) then {
          private _category = [_x] call OCAP_recorder_client_getItemCategory;
          if (_category isNotEqualTo "items") then {_entry set ["cat", _category]};
        };
        _entry
      }
    };

    private _describeContainer = {
      params ["_className", "_items"];
      [createHashMapFromArray [
        ["class", _className],
        ["items", [_items, true] call _describeItems]
      ], _className] call OCAP_recorder_client_setDisplayName
    };

    private _describeWorn = {
      params ["_className"];
      [createHashMapFromArray [["class", _className]], _className] call
        OCAP_recorder_client_setDisplayName
    };

    private _weapons = [];
    {
      _x params ["_slot", "_className", "_attachments"];
      if (_className isNotEqualTo "") then {
        _weapons pushBack ([createHashMapFromArray [
          ["class", _className],
          ["slot", _slot],
          ["attachments", [_attachments select {_x isNotEqualTo ""}] call _describeItems]
        ], _className] call OCAP_recorder_client_setDisplayName);
      };
    } forEach [
      ["primary", primaryWeapon _unit, primaryWeaponItems _unit],
      ["handgun", handgunWeapon _unit, handgunItems _unit],
      ["launcher", secondaryWeapon _unit, secondaryWeaponItems _unit],
      ["binocular", binocular _unit, []]
    ];

    // magazinesAmmoFull entries are [class, ammoCount, isLoaded, ...]. Totalled
    // per class in one pass, in first-seen order; selecting the matching
    // magazines out of the full list once per class re-walked it every time.
    private _magazineStats = createHashMap;
    private _magazineOrder = [];
    {
      private _className = _x param [0, ""];
      if (_className isEqualTo "") then {continue};
      private _stats = _magazineStats get _className;
      if (isNil "_stats") then {
        _stats = [0, 0, 0];
        _magazineStats set [_className, _stats];
        _magazineOrder pushBack _className;
      };
      _stats set [0, (_stats select 0) + 1];
      _stats set [1, (_stats select 1) + (_x param [1, 0])];
      if (_x param [2, false]) then {_stats set [2, (_stats select 2) + 1]};
    } forEach magazinesAmmoFull _unit;

    private _magazines = _magazineOrder apply {
      (_magazineStats get _x) params ["_count", "_totalRounds", "_loadedCount"];
      private _entry = createHashMapFromArray [
        ["class", _x],
        ["count", _count],
        ["totalRounds", _totalRounds],
        ["loadedCount", _loadedCount]
      ];
      [_entry, _x] call OCAP_recorder_client_setDisplayName;
      private _category = [_x] call OCAP_recorder_client_getItemCategory;
      if (_category isNotEqualTo "items") then {_entry set ["cat", _category]};
      _entry
    };

    private _result = createHashMapFromArray [
      ["reason", _reason],
      // loadAbs is in engine mass units (a tenth of a pound each), not kilograms.
      ["massUnits", loadAbs _unit],
      ["load", load _unit],
      ["uniform", [uniform _unit, uniformItems _unit] call _describeContainer],
      ["vest", [vest _unit, vestItems _unit] call _describeContainer],
      ["backpack", [backpack _unit, backpackItems _unit] call _describeContainer],
      ["headgear", [headgear _unit] call _describeWorn],
      ["goggles", [goggles _unit] call _describeWorn],
      ["weapons", _weapons],
      ["magazines", _magazines],
      ["assignedItems", [assignedItems _unit] call _describeItems]
    ];

    if (missionNamespace getVariable [QEGVAR(settings,trackPlayerTraits), true]) then {
      _result set ["traits", [_unit] call OCAP_recorder_client_buildTraits];
    };

    _result
  };

  OCAP_recorder_client_aceWoundTypes = [
    "Abrasion", "Avulsion", "Contusion", "Crush", "Cut",
    "Laceration", "Velocity Wound", "Puncture Wound", "Thermal Burn"
  ];
  OCAP_recorder_client_aceWoundSizes = ["Minor", "Medium", "Large"];

  // ACE encodes a wound class as woundTypeIndex * 10 + sizeCategory.
  OCAP_recorder_client_aceWoundName = {
    params [["_classId", -1, [0]]];
    if (_classId < 0) exitWith {"Wound"};
    private _type = OCAP_recorder_client_aceWoundTypes param [floor (_classId / 10), "Wound"];
    private _size = OCAP_recorder_client_aceWoundSizes param [_classId mod 10, ""];
    if (_size isEqualTo "") exitWith {_type};
    format ["%1 %2", _size, _type]
  };

  OCAP_recorder_client_partItem = {
    params ["_kind", "_name", ["_count", 0], ["_detail", ""]];
    private _item = createHashMapFromArray [["kind", _kind], ["name", _name]];
    if (_count > 0) then {_item set ["count", _count]};
    if (_detail isNotEqualTo "") then {_item set ["detail", _detail]};
    _item
  };

  // ACE stores [_message, _timeStamp, _arguments, _logType] on the patient and
  // localizes at display time. Do the same here so the recording is readable.
  OCAP_recorder_client_formatMedicalLog = {
    params ["_unit", "_type"];
    private _log = _unit getVariable [format ["ace_medical_log_%1", _type], []];
    _log apply {
      _x params ["_message", "_timeStamp", ["_arguments", []]];
      if (_message isEqualType "" && {isLocalized _message}) then {
        _message = localize _message;
      };
      private _args = _arguments apply {
        if (_x isEqualType "" && {isLocalized _x}) then {localize _x} else {_x}
      };
      private _text = if (_args isEqualTo []) then {_message} else {format ([_message] + _args)};
      createHashMapFromArray [["time", _timeStamp], ["text", _text]]
    }
  };

  /*
    Everything that mods attach to, insert into or inject at a specific body part is
    collected here. Each collector is [id, code]; the code receives the unit and
    returns [[bodyPartIndex, item], ...]. Supporting another treatment or another
    medical mod means appending one collector - the snapshot builder and the web UI
    both render whatever comes out without knowing what it is.
  */
  OCAP_recorder_client_medicalPartCollectors = [];

  if (OCAP_recorder_client_hasAceMedical) then {
    OCAP_recorder_client_medicalPartCollectors append [
      ["aceTourniquet", {
        params ["_unit"];
        private _result = [];
        {
          if (_x > 0) then {
            _result pushBack [_forEachIndex, ["tourniquet", "Tourniquet"] call OCAP_recorder_client_partItem];
          };
        } forEach (_unit getVariable ["ace_medical_tourniquets", [0, 0, 0, 0, 0, 0]]);
        _result
      }],

      ["aceFracture", {
        params ["_unit"];
        private _result = [];
        {
          // 1 is an untreated fracture, -1 a splinted one, 0 nothing.
          switch (true) do {
            case (_x > 0): {
              _result pushBack [_forEachIndex, ["fracture", "Fracture"] call OCAP_recorder_client_partItem];
            };
            case (_x < 0): {
              _result pushBack [_forEachIndex, ["splint", "Splint"] call OCAP_recorder_client_partItem];
            };
            default {};
          };
        } forEach (_unit getVariable ["ace_medical_fractures", [0, 0, 0, 0, 0, 0]]);
        _result
      }],

      ["aceOpenWound", {
        params ["_unit"];
        private _result = [];
        {
          private _partIndex = OCAP_recorder_client_bodyParts find _x;
          private _wounds = _y;
          if (_partIndex >= 0) then {
            private _aggregated = createHashMap;
            {
              _x params [["_classId", -1], ["_amountOf", 0], ["_bloodloss", 0]];
              if (_amountOf > 0) then {
                private _name = [_classId] call OCAP_recorder_client_aceWoundName;
                private _totals = _aggregated getOrDefault [_name, [0, 0], true];
                _totals set [0, (_totals select 0) + _amountOf];
                _totals set [1, (_totals select 1) + _bloodloss];
              };
            } forEach _wounds;
            {
              private _detail = "";
              if ((_y select 1) > 0) then {_detail = format ["bleeding %1", (_y select 1) toFixed 3]};
              _result pushBack [_partIndex, ["wound", _x, round (_y select 0), _detail] call OCAP_recorder_client_partItem];
            } forEach _aggregated;
          };
        } forEach (_unit getVariable ["ace_medical_openWounds", createHashMap]);
        _result
      }],

      ["aceBandagedWound", {
        params ["_unit"];
        private _result = [];
        {
          private _partIndex = OCAP_recorder_client_bodyParts find _x;
          private _wounds = _y;
          if (_partIndex >= 0) then {
            private _count = 0;
            {_count = _count + (_x param [1, 0])} forEach _wounds;
            if (_count > 0) then {
              _result pushBack [_partIndex, ["bandage", "Bandaged wound", round _count] call OCAP_recorder_client_partItem];
            };
          };
        } forEach (_unit getVariable ["ace_medical_bandagedWounds", createHashMap]);
        _result
      }],

      ["aceStitchedWound", {
        params ["_unit"];
        private _result = [];
        {
          private _partIndex = OCAP_recorder_client_bodyParts find _x;
          private _wounds = _y;
          if (_partIndex >= 0) then {
            private _count = 0;
            {_count = _count + (_x param [1, 0])} forEach _wounds;
            if (_count > 0) then {
              _result pushBack [_partIndex, ["suture", "Stitched wound", round _count] call OCAP_recorder_client_partItem];
            };
          };
        } forEach (_unit getVariable ["ace_medical_stitchedWounds", createHashMap]);
        _result
      }],

      ["aceIv", {
        params ["_unit"];
        private _result = [];
        {
          _x params [["_volume", 0], ["_fluid", ""], ["_partIndex", -1], "", "", ["_itemClass", ""]];
          if (_partIndex >= 0) then {
            private _name = _fluid;
            if (_itemClass isNotEqualTo "") then {
              _name = [_itemClass] call OCAP_recorder_client_gearDisplayName;
            };
            _result pushBack [_partIndex, ["iv", _name, 0, format ["%1 ml left", round _volume]] call OCAP_recorder_client_partItem];
          };
        } forEach (_unit getVariable ["ace_medical_ivBags", []]);
        _result
      }],

      ["aceOccludedMedication", {
        params ["_unit"];
        private _result = [];
        {
          _x params [["_partIndex", -1], ["_className", ""]];
          if (_partIndex >= 0) then {
            _result pushBack [_partIndex, ["medicationBlocked", _className, 0, "blocked by tourniquet"] call OCAP_recorder_client_partItem];
          };
        } forEach (_unit getVariable ["ace_medical_occludedMedications", []]);
        _result
      }]
    ];
  };

  if (OCAP_recorder_client_hasKatMedical) then {
    OCAP_recorder_client_katIvAccess = ["", "IO access", "IV access 16g", "IV access with block", "IV access flushed"];

    OCAP_recorder_client_medicalPartCollectors append [
      ["katIvAccess", {
        params ["_unit"];
        private _result = [];
        {
          private _label = OCAP_recorder_client_katIvAccess param [round _x, ""];
          if (_label isNotEqualTo "") then {
            _result pushBack [_forEachIndex, ["ivAccess", _label] call OCAP_recorder_client_partItem];
          };
        } forEach (_unit getVariable ["kat_pharma_IV", [0, 0, 0, 0, 0, 0]]);
        _result
      }],

      ["katSurgicalFracture", {
        params ["_unit"];
        private _result = [];
        {
          if (_x > 0) then {
            _result pushBack [_forEachIndex, ["surgicalFracture", "Fracture (surgical)", 0, format ["stage %1", _x]] call OCAP_recorder_client_partItem];
          };
        } forEach (_unit getVariable ["kat_surgery_fractures", [0, 0, 0, 0, 0, 0]]);
        _result
      }],

      ["katChestSeal", {
        params ["_unit"];
        if !(_unit getVariable ["kat_breathing_activeChestSeal", false]) exitWith {[]};
        // The torso is the only part a chest seal can go on.
        [[1, ["chestSeal", "Chest seal"] call OCAP_recorder_client_partItem]]
      }],

      ["katAirway", {
        params ["_unit"];
        private _item = _unit getVariable ["kat_airway_airway_item", ""];
        if (_item isEqualTo "") exitWith {[]};
        [[0, ["airway", _item] call OCAP_recorder_client_partItem]]
      }],

      ["katOverstretch", {
        params ["_unit"];
        if !(_unit getVariable ["kat_airway_overstretch", false]) exitWith {[]};
        [[0, ["airway", "Head-tilt chin-lift"] call OCAP_recorder_client_partItem]]
      }],

      ["katNasalCannula", {
        params ["_unit"];
        if !(_unit getVariable ["kat_breathing_nasalCannula", false]) exitWith {[]};
        [[0, ["oxygen", "Nasal cannula"] call OCAP_recorder_client_partItem]]
      }],

      ["katPulseOx", {
        params ["_unit"];
        private _result = [];
        {
          if (_x > 0) then {
            _result pushBack [_forEachIndex + 2, ["monitor", "Pulse oximeter"] call OCAP_recorder_client_partItem];
          };
        } forEach (_unit getVariable ["kat_breathing_PulseOximeter_Attached", [0, 0]]);
        _result
      }],

      ["katSurgicalBlock", {
        params ["_unit"];
        private _result = [];
        {
          if (_x > 0) then {
            _result pushBack [_forEachIndex, ["reboa", "REBOA / surgical block"] call OCAP_recorder_client_partItem];
          };
        } forEach (_unit getVariable ["kat_surgery_surgicalBlock", [0, 0, 0, 0, 0, 0]]);
        _result
      }]
    ];
  };

  /*
    Systemic treatments that are not tied to a body part. Same [id, code] shape as
    the per-part collectors, but the code returns a plain list of items.
  */
  OCAP_recorder_client_medicalTreatmentCollectors = [];

  if (OCAP_recorder_client_hasAceMedical) then {
    OCAP_recorder_client_medicalTreatmentCollectors pushBack ["aceMedication", {
      params ["_unit"];
      // ACE stores [class, startedAt, timeToMax, maxTimeInSystem, ...]. Remaining
      // time is the useful bit on replay; count is aggregated per class.
      private _aggregated = createHashMap;
      {
        _x params [["_className", ""], ["_startedAt", 0], "", ["_maxTime", 0]];
        if (_className isEqualTo "") then {continue};
        private _remaining = (_maxTime - (CBA_missionTime - _startedAt)) max 0;
        private _totals = _aggregated getOrDefault [_className, [0, 0], true];
        _totals set [0, (_totals select 0) + 1];
        _totals set [1, (_totals select 1) max _remaining];
      } forEach (_unit getVariable ["ace_medical_medications", []]);
      private _result = [];
      {
        private _name = _x;
        private _itemClass = if (isClass (configFile >> "CfgWeapons" >> _x)) then {_x} else {
          format ["ACE_%1", _x]
        };
        if (isClass (configFile >> "CfgWeapons" >> _itemClass)) then {
          _name = [_itemClass] call OCAP_recorder_client_gearDisplayName;
        };
        private _detail = "";
        if ((_y select 1) > 0) then {_detail = format ["%1 s left", round (_y select 1)]};
        _result pushBack (["medication", _name, _y select 0, _detail] call OCAP_recorder_client_partItem);
      } forEach _aggregated;
      _result
    }];
  };

  OCAP_recorder_client_buildMedicalSnapshot = {
    params ["_unit", "_reason"];

    private _partItems = OCAP_recorder_client_bodyParts apply {[]};
    {
      _x params ["_id", "_collector"];
      {
        _x params ["_index", "_item"];
        if (_index >= 0 && {_index < count _partItems}) then {
          (_partItems select _index) pushBack _item;
        };
      } forEach ([_unit] call _collector);
    } forEach OCAP_recorder_client_medicalPartCollectors;

    private _treatments = [];
    {
      _x params ["_id", "_collector"];
      _treatments append ([_unit] call _collector);
    } forEach OCAP_recorder_client_medicalTreatmentCollectors;

    // ACE is the only source of per-part damage; without it a part carries items only.
    private _bodyPartDamage = [];
    if (OCAP_recorder_client_hasAceMedical) then {
      _bodyPartDamage = _unit getVariable ["ace_medical_bodyPartDamage", [0, 0, 0, 0, 0, 0]];
    };
    private _bodyParts = [];
    {
      private _entry = createHashMapFromArray [["part", _x], ["items", _partItems select _forEachIndex]];
      if (_bodyPartDamage isNotEqualTo []) then {
        _entry set ["damage", _bodyPartDamage param [_forEachIndex, 0]];
      };
      _bodyParts pushBack _entry;
    } forEach OCAP_recorder_client_bodyParts;

    private _hitPoints = getAllHitPointsDamage _unit;
    private _result = createHashMapFromArray [
      ["reason", _reason],
      ["bodyParts", _bodyParts],
      ["treatments", _treatments],
      ["vanilla", createHashMapFromArray [
        ["damage", damage _unit],
        ["alive", alive _unit],
        ["lifeState", lifeState _unit],
        ["incapacitated", lifeState _unit isEqualTo "INCAPACITATED"],
        ["hitPointNames", _hitPoints param [0, []]],
        ["hitPointDamage", _hitPoints param [2, []]]
      ]]
    ];

    if (OCAP_recorder_client_hasAceMedical) then {
      _result set ["ace", createHashMapFromArray [
        ["bloodVolume", _unit getVariable ["ace_medical_bloodVolume", 6]],
        ["heartRate", _unit getVariable ["ace_medical_heartRate", 80]],
        ["bloodPressure", _unit getVariable ["ace_medical_bloodPressure", [80, 120]]],
        ["pain", _unit getVariable ["ace_medical_pain", 0]],
        ["painSuppress", _unit getVariable ["ace_medical_painSuppress", 0]],
        ["unconscious", _unit getVariable ["ACE_isUnconscious", false]],
        ["cardiacArrest", _unit getVariable ["ace_medical_inCardiacArrest", false]],
        ["bleedingRate", _unit getVariable ["ace_medical_woundBleeding", 0]],
        // 0 healthy through 4 massive blood loss.
        ["hemorrhage", _unit getVariable ["ace_medical_hemorrhage", 0]],
        ["limping", _unit getVariable ["ace_medical_isLimping", false]],
        ["triageLevel", _unit getVariable ["ace_medical_triageLevel", 0]]
      ]];
      if (!OCAP_recorder_client_hasKatMedical) then {
        (_result get "ace") set ["spo2", _unit getVariable ["ace_medical_spo2", 97]];
      };
      _result set ["activity", [_unit, "activity"] call OCAP_recorder_client_formatMedicalLog];
      _result set ["quickView", [_unit, "quick_view"] call OCAP_recorder_client_formatMedicalLog];
    } else {
      _result set ["bodyParts", OCAP_recorder_client_bodyParts apply {
        createHashMapFromArray [["part", _x], ["items", _partItems select _forEachIndex]]
      }];
    };

    if (OCAP_recorder_client_hasKatMedical) then {
      private _bloodGas = _unit getVariable ["kat_circulation_bloodGas", [40, 90, 0.96, 24, 7.4, 37]];
      private _bodyFluid = _unit getVariable ["kat_circulation_bodyFluid", [2700, 3300, 500, 10000, 6000]];
      _result set ["kat", createHashMapFromArray [
        ["airwaySecured", _unit getVariable ["kat_airway_airway", false]],
        ["airwayItem", _unit getVariable ["kat_airway_airway_item", ""]],
        ["airwayObstruction", _unit getVariable ["kat_airway_obstruction", false]],
        ["airwayOccluded", _unit getVariable ["kat_airway_occluded", false]],
        ["pneumothorax", _unit getVariable ["kat_breathing_pneumothorax", 0]],
        ["hemopneumothorax", _unit getVariable ["kat_breathing_hemopneumothorax", false]],
        ["tensionPneumothorax", _unit getVariable ["kat_breathing_tensionpneumothorax", false]],
        ["chestSeal", _unit getVariable ["kat_breathing_activeChestSeal", false]],
        ["breathRate", _unit getVariable ["kat_breathing_breathRate", 15]],
        // Blood gas is [PaCO2, PaO2, O2 saturation, HCO3, pH, EtCO2].
        ["spo2", (_bloodGas param [2, 0.96]) * 100],
        ["etco2", _bloodGas param [5, 37]],
        ["paco2", _bloodGas param [0, 40]],
        ["pao2", _bloodGas param [1, 90]],
        ["ph", _bloodGas param [4, 7.4]],
        ["bloodMl", _bodyFluid param [4, 6000]],
        ["bloodType", _unit getVariable ["kat_circulation_bloodtype", ""]],
        ["internalBleeding", _unit getVariable ["kat_circulation_internalBleeding", 0]]
      ]];
    };

    _result
  };

  // Stance rides along with the stamina snapshot because posture is what the
  // stamina drain has to be read against. It is written as a small integer enum
  // so a value that is sampled this often costs one number instead of a string:
  // 0 unknown (in a vehicle, or an animation with no stance), 1 stand, 2 crouch, 3 prone.
  OCAP_recorder_client_stanceCode = {
    params ["_unit"];
    switch (toUpper stance _unit) do {
      case "STAND": {1};
      case "CROUCH": {2};
      case "PRONE": {3};
      default {0};
    };
  };

  OCAP_recorder_client_buildStaminaSnapshot = {
    params ["_unit", "_reason"];

    // getStamina is seconds of sprint left, and the ceiling shrinks with carried load,
    // so the raw value is only readable next to the maximum it was measured against.
    private _staminaDuration = getNumber (configFile >> "CfgVehicles" >> "CAManBase" >> "staminaDuration");
    if (_staminaDuration <= 0) then {_staminaDuration = 60};
    private _load = load _unit;

    private _result = createHashMapFromArray [
      ["reason", _reason],
      ["vanilla", createHashMapFromArray [
        ["stamina", getStamina _unit],
        ["staminaMax", _staminaDuration * ((1 - _load) max 0)],
        ["fatigue", getFatigue _unit],
        ["load", _load],
        ["massUnits", loadAbs _unit],
        ["stance", [_unit] call OCAP_recorder_client_stanceCode]
      ]]
    ];

    if (OCAP_recorder_client_hasAceFatigue) then {
      _result set ["ace", createHashMapFromArray [
        ["anaerobicReserve", missionNamespace getVariable ["ace_advanced_fatigue_anReservePercentage", 1]],
        ["aerobicReserve", missionNamespace getVariable ["ace_advanced_fatigue_aeReservePercentage", 1]],
        ["muscleDamage", missionNamespace getVariable ["ace_advanced_fatigue_muscleDamage", 0]],
        ["performanceFactor", _unit getVariable ["ace_advanced_fatigue_performanceFactor", missionNamespace getVariable ["ace_advanced_fatigue_performanceFactor", 1]]]
      ]];
    };

    _result
  };

  // Walk tf_parent / config inheritance so an instanced radio like TFAR_anprc152_1
  // still yields the prototype's tf_range.
  OCAP_recorder_client_configNumberInherited = {
    params ["_config", "_property"];
    private _cursor = _config;
    private _value = 0;
    while {isClass _cursor && {_value <= 0}} do {
      if (isNumber (_cursor >> _property)) then {
        _value = getNumber (_cursor >> _property);
      };
      if (_value <= 0) then {
        private _parentName = getText (_cursor >> "tf_parent");
        if (_parentName isNotEqualTo "" && {_parentName isNotEqualTo configName _cursor}) then {
          private _parentConfig = configFile >> "CfgWeapons" >> _parentName;
          if (!isClass _parentConfig) then {_parentConfig = configFile >> "CfgVehicles" >> _parentName};
          _cursor = _parentConfig;
        } else {
          _cursor = inheritsFrom _cursor;
        };
      };
    };
    _value
  };

  OCAP_recorder_client_configTextInherited = {
    params ["_config", "_property"];
    private _cursor = _config;
    private _value = "";
    while {isClass _cursor && {_value isEqualTo ""}} do {
      if (isText (_cursor >> _property)) then {
        _value = getText (_cursor >> _property);
      };
      if (_value isEqualTo "") then {
        private _parentName = getText (_cursor >> "tf_parent");
        if (_parentName isNotEqualTo "" && {_parentName isNotEqualTo configName _cursor}) then {
          private _parentConfig = configFile >> "CfgWeapons" >> _parentName;
          if (!isClass _parentConfig) then {_parentConfig = configFile >> "CfgVehicles" >> _parentName};
          _cursor = _parentConfig;
        } else {
          _cursor = inheritsFrom _cursor;
        };
      };
    };
    _value
  };

  OCAP_recorder_client_tfarMultiplier = {
    if (!isNil "TFAR_fnc_getTransmittingDistanceMultiplicator") exitWith {
      call TFAR_fnc_getTransmittingDistanceMultiplicator
    };
    if (!isNil "TFAR_currentUnit") exitWith {
      TFAR_currentUnit getVariable ["tf_sendingDistanceMultiplicator", 1]
    };
    1
  };

  // Same lookup TFAR uses when it draws a transmit: the radio's own tf_range,
  // scaled by the mission sending-distance multiplicator.
  OCAP_recorder_client_getTfarRange = {
    params ["_radio", "_kind", "_fallback"];
    private _range = 0;
    if (_kind isEqualTo "SW") then {
      if (!isNil "TFAR_fnc_getWeaponConfigProperty") then {
        _range = [_radio, "tf_range", 0] call TFAR_fnc_getWeaponConfigProperty;
      };
      if (_range <= 0 && {_radio isEqualType ""}) then {
        _range = [configFile >> "CfgWeapons" >> _radio, "tf_range"] call OCAP_recorder_client_configNumberInherited;
      };
    } else {
      if (!isNil "TFAR_fnc_getLrRadioProperty") then {
        _range = [_radio, "tf_range", 0] call TFAR_fnc_getLrRadioProperty;
      };
      if (_range <= 0) then {
        private _className = if (_radio isEqualType "") then {_radio} else {typeOf _radio};
        _range = [configFile >> "CfgVehicles" >> _className, "tf_range"] call OCAP_recorder_client_configNumberInherited;
      };
    };
    if (_range <= 0) then {_range = _fallback};
    _range * (call OCAP_recorder_client_tfarMultiplier)
  };

  // Live TFAR settings can cache an empty code if the side variable was not
  // ready when the radio was first programmed. Re-read the config variable
  // unless the mission has encryption turned off.
  OCAP_recorder_client_getTfarCode = {
    params ["_radio", "_kind"];
    if (missionNamespace getVariable ["TFAR_radioCodesDisabled", false]) exitWith {""};

    private _code = "";
    if (_kind isEqualTo "SW") then {
      if (!isNil "TFAR_fnc_getSwRadioCode") then {_code = _radio call TFAR_fnc_getSwRadioCode};
    } else {
      if (!isNil "TFAR_fnc_getLrRadioCode") then {_code = _radio call TFAR_fnc_getLrRadioCode};
    };
    if (!(_code isEqualType "") || {_code isNotEqualTo ""}) exitWith {
      if (_code isEqualType "") then {_code} else {str _code}
    };

    private _codeVar = "";
    if (_kind isEqualTo "SW") then {
      if (!isNil "TFAR_fnc_getWeaponConfigProperty") then {
        _codeVar = [_radio, "tf_encryptionCode", ""] call TFAR_fnc_getWeaponConfigProperty;
      };
      if (!(_codeVar isEqualType "") || {_codeVar isEqualTo ""}) then {
        if (_radio isEqualType "") then {
          _codeVar = [configFile >> "CfgWeapons" >> _radio, "tf_encryptionCode"] call OCAP_recorder_client_configTextInherited;
        };
      };
    } else {
      private _className = if (_radio isEqualType "") then {_radio} else {
        if (_radio isEqualType [] && {count _radio >= 1}) then {
          private _object = _radio select 0;
          if (_object isEqualType "") then {_object} else {typeOf _object}
        } else {
          if (_radio isEqualType objNull) then {typeOf _radio} else {""}
        }
      };
      if (!isNil "TFAR_fnc_getLrRadioProperty") then {
        _codeVar = [_radio, "tf_encryptionCode", ""] call TFAR_fnc_getLrRadioProperty;
      };
      if (!(_codeVar isEqualType "") || {_codeVar isEqualTo ""}) then {
        _codeVar = [configFile >> "CfgVehicles" >> _className, "tf_encryptionCode"] call OCAP_recorder_client_configTextInherited;
      };
    };
    if (!(_codeVar isEqualType "") || {_codeVar isEqualTo ""}) exitWith {""};
    if (_codeVar isEqualTo "tf_guer_radio_code") then {_codeVar = "tf_independent_radio_code"};
    missionNamespace getVariable [_codeVar, _codeVar]
  };

  // ACRE publishes transmit power, not a circle. 5 W (PRC-152 default) maps to
  // 5 km, the same scale as a TFAR 152, via free-space sqrt(power).
  OCAP_recorder_client_getAcreRange = {
    params ["_power", "_fallback"];
    if (_power > 0) exitWith {70.710678118 * sqrt _power};
    _fallback
  };

  // One carried TFAR SW (and its additional channel, if set). Called for every
  // radio TFAR_fnc_radiosList returns, not only the currently selected one.
  OCAP_recorder_client_pushTfarSwRadio = {
    params ["_radios", "_sw", "_swFallback", "_isActive"];
    if (!(_sw isEqualType "") || {_sw isEqualTo ""} || {isNil "TFAR_fnc_getSwChannel"}) exitWith {};

    private _channel = _sw call TFAR_fnc_getSwChannel;
    private _additional = -1;
    if (!isNil "TFAR_fnc_getAdditionalSwChannel") then {
      _additional = _sw call TFAR_fnc_getAdditionalSwChannel;
    };
    private _entry = [createHashMapFromArray [["class", _sw]], _sw] call
      OCAP_recorder_client_setDisplayName;
    _entry set ["mod", "TFAR"];
    _entry set ["type", "SW"];
    _entry set ["channel", _channel + 1];
    _entry set ["frequency", parseNumber ([_sw, _channel + 1] call TFAR_fnc_getChannelFrequency)];
    _entry set ["code", [_sw, "SW"] call OCAP_recorder_client_getTfarCode];
    _entry set ["rangeMeters", [_sw, "SW", _swFallback] call OCAP_recorder_client_getTfarRange];
    _entry set ["additional", false];
    _entry set ["active", _isActive];
    _radios pushBack _entry;

    if (!isNil "_additional" && {_additional > -1}) then {
      private _additionalEntry = +_entry;
      _additionalEntry set ["channel", _additional + 1];
      _additionalEntry set ["frequency", parseNumber ([_sw, _additional + 1] call TFAR_fnc_getChannelFrequency)];
      _additionalEntry set ["additional", true];
      _additionalEntry set ["active", false];
      _radios pushBack _additionalEntry;
    };
  };

  OCAP_recorder_client_buildRadioSnapshot = {
    params ["_unit", "_reason"];
    private _radios = [];

    if (OCAP_recorder_client_hasTfar) then {
      private _swFallback = missionNamespace getVariable [QEGVAR(settings,radioShortRangeMeters), 5000];
      private _lrFallback = missionNamespace getVariable [QEGVAR(settings,radioLongRangeMeters), 20000];

      private _activeSw = "";
      if (!isNil "TFAR_fnc_activeSwRadio") then {
        private _sw = call TFAR_fnc_activeSwRadio;
        if (!isNil "_sw" && {_sw isEqualType ""} && {_sw isNotEqualTo ""}) then {
          _activeSw = _sw;
        };
      };

      private _swRadios = [];
      if (!isNil "TFAR_fnc_radiosList") then {
        _swRadios = _unit call TFAR_fnc_radiosList;
      };
      if (!(_swRadios isEqualType [])) then {_swRadios = []};
      if (_swRadios isEqualTo [] && {_activeSw isNotEqualTo ""}) then {
        _swRadios = [_activeSw];
      };
      {
        [_radios, _x, _swFallback, _x isEqualTo _activeSw] call OCAP_recorder_client_pushTfarSwRadio;
      } forEach _swRadios;

      private _lr = [];
      if (!isNil "TFAR_fnc_activeLrRadio") then {
        _lr = call TFAR_fnc_activeLrRadio;
      };
      if (!isNil "_lr" && {_lr isEqualType []} && {count _lr >= 2}) then {
        private _channel = _lr call TFAR_fnc_getLrChannel;
        private _additional = _lr call TFAR_fnc_getAdditionalLrChannel;
        private _radioObject = _lr select 0;
        private _className = if (_radioObject isEqualType "") then {_radioObject} else {typeOf _radioObject};
        private _entry = [createHashMapFromArray [["class", _className]], _className] call
          OCAP_recorder_client_setDisplayName;
        _entry set ["mod", "TFAR"];
        _entry set ["type", "LR"];
        _entry set ["channel", _channel + 1];
        _entry set ["frequency", parseNumber ([_lr, _channel + 1] call TFAR_fnc_getChannelFrequency)];
        _entry set ["code", [_lr, "LR"] call OCAP_recorder_client_getTfarCode];
        _entry set ["rangeMeters", [_radioObject, "LR", _lrFallback] call OCAP_recorder_client_getTfarRange];
        _entry set ["additional", false];
        _entry set ["active", true];
        _radios pushBack _entry;

        if (!isNil "_additional" && {_additional > -1}) then {
          private _additionalEntry = +_entry;
          _additionalEntry set ["channel", _additional + 1];
          _additionalEntry set ["frequency", parseNumber ([_lr, _additional + 1] call TFAR_fnc_getChannelFrequency)];
          _additionalEntry set ["additional", true];
          _additionalEntry set ["active", false];
          _radios pushBack _additionalEntry;
        };
      };
    };

    // ACRE is initialised per-client. Skip until every radio on the unit has an ID.
    if (OCAP_recorder_client_hasAcre && {!isNil "acre_api_fnc_getCurrentRadioList"} && {
      isNil "acre_api_fnc_isInitialized" || {[] call acre_api_fnc_isInitialized}
    }) then {
      private _srFallback = missionNamespace getVariable [QEGVAR(settings,radioShortRangeMeters), 5000];
      private _lrFallback = missionNamespace getVariable [QEGVAR(settings,radioLongRangeMeters), 20000];
      private _active = "";
      if (!isNil "acre_api_fnc_getCurrentRadio") then {_active = call acre_api_fnc_getCurrentRadio};

      {
        private _radioId = _x;
        private _baseClass = _radioId;
        if (!isNil "acre_api_fnc_getBaseRadio") then {
          _baseClass = [_radioId] call acre_api_fnc_getBaseRadio;
        };
        // ACRE's own getDisplayName resolves through the client's stringtable,
        // so it is not asked; the name comes from config the same way as any
        // other item, which keeps it out of the server's language.
        private _entry = [createHashMapFromArray [["class", _baseClass]], _baseClass] call
          OCAP_recorder_client_setDisplayName;
        private _isPack = getNumber (configFile >> "CfgAcreComponents" >> _baseClass >> "isPackRadio") == 1;
        _entry set ["mod", "ACRE"];
        _entry set ["type", ["SR", "LR"] select _isPack];
        _entry set ["active", _radioId isEqualTo _active];
        _entry set ["channel", [_radioId] call acre_api_fnc_getRadioChannel];
        _entry set ["frequency", 0];
        _entry set ["code", ""];
        _entry set ["additional", false];

        private _power = 0;
        // The live channel is an ACRE fast hash, which is a location holding variables.
        if (!isNil "acre_sys_data_fnc_dataEvent") then {
          private _channelData = [_radioId, "getCurrentChannelData"] call acre_sys_data_fnc_dataEvent;
          if (!isNil "_channelData" && {_channelData isEqualType locationNull} && {!isNull _channelData}) then {
            _entry set ["frequency", _channelData getVariable ["frequencyTX", 0]];
            _power = _channelData getVariable ["power", 0];
            _entry set ["powerMilliwatts", _power];
            _entry set ["code", str (_channelData getVariable ["encryption", ""])];
          };
        };
        _entry set ["rangeMeters", [_power, [_srFallback, _lrFallback] select _isPack] call OCAP_recorder_client_getAcreRange];

        _radios pushBack _entry;
      } forEach (call acre_api_fnc_getCurrentRadioList);
    };

    createHashMapFromArray [["reason", _reason], ["radios", _radios]]
  };

  OCAP_recorder_client_capturePlayerState = {
    params [
      ["_reason", "periodic", [""]],
      ["_kinds", ["inventory", "medical", "stamina", "radio"], [[]]],
      ["_unit", player, [objNull]]
    ];

    // Killed fires before the engine drops the current weapon. Reschedule into
    // a scheduled environment and wait a tick so the death kit matches the corpse.
    if (_reason isEqualTo "death" && {!canSuspend}) exitWith {
      _this spawn OCAP_recorder_client_capturePlayerState;
    };
    if (_reason isEqualTo "death") then { sleep 0.3; };

    private _isRecording = (missionNamespace getVariable [QEGVAR(recorder,recording), false]) &&
      {(missionNamespace getVariable [QEGVAR(recorder,startTime), -1]) > -1};
    if (!hasInterface || {isNull _unit} || {!local _unit} || {!_isRecording}) exitWith {};

    {
      private _enabled = switch (_x) do {
        case "inventory": {
          (missionNamespace getVariable [QEGVAR(settings,trackPlayerInventory), true]) || {
            _reason isEqualTo "death" && {missionNamespace getVariable [QEGVAR(settings,trackPlayerInventoryOnDeath), true]}
          }
        };
        case "medical": {missionNamespace getVariable [QEGVAR(settings,trackPlayerMedical), true]};
        case "stamina": {missionNamespace getVariable [QEGVAR(settings,trackPlayerStamina), true]};
        case "radio": {
          (missionNamespace getVariable [QEGVAR(settings,trackPlayerRadio), true]) &&
            {OCAP_recorder_client_hasTfar || OCAP_recorder_client_hasAcre}
        };
        default {false};
      };

      if (_enabled) then {
        private _payload = switch (_x) do {
          case "inventory": {[_unit, _reason] call OCAP_recorder_client_buildInventorySnapshot};
          case "medical": {[_unit, _reason] call OCAP_recorder_client_buildMedicalSnapshot};
          case "stamina": {[_unit, _reason] call OCAP_recorder_client_buildStaminaSnapshot};
          case "radio": {[_unit, _reason] call OCAP_recorder_client_buildRadioSnapshot};
        };

        // TFAR and ACRE finish initialising after the first snapshot window, so an
        // empty radio list at the start of a recording is a sampler that is not
        // ready yet, not a player without a radio. Write nothing until the unit has
        // actually carried one; after that an empty list is a real change and is
        // recorded, because putting the radio down is worth seeing.
        private _write = true;
        if (_x isEqualTo "radio") then {
          if ((_payload getOrDefault ["radios", []]) isEqualTo []) then {
            _write = OCAP_recorder_client_radioSeen;
          } else {
            OCAP_recorder_client_radioSeen = true;
          };
        };

        if (_write) then {
          [_x, _unit, _payload] remoteExecCall [QFUNC(submitPlayerSnapshot), 2];
        };
      };
    } forEach _kinds;
  };

  // Cheap fingerprints so a Zeus-to-slot loadout, a radio frequency change, a
  // wake-up, or a new ACE activity / quick-view line is written within one PFH tick.
  OCAP_recorder_client_inventoryFingerprint = {
    params ["_unit"];
    // Traits are part of the inventory snapshot, so a Zeus promoting someone to
    // medic mid-mission has to trip the same diff a loadout change does.
    private _traits = [];
    if (missionNamespace getVariable [QEGVAR(settings,trackPlayerTraits), true]) then {
      _traits = [
        getAllUnitTraits _unit,
        _unit getVariable ["ace_medical_medicClass", -1],
        _unit getVariable ["ACE_IsEngineer", -1],
        _unit getVariable ["ACE_isEOD", -1]
      ];
    };
    [
      _traits,
      loadAbs _unit,
      uniform _unit,
      vest _unit,
      backpack _unit,
      headgear _unit,
      goggles _unit,
      primaryWeapon _unit,
      handgunWeapon _unit,
      secondaryWeapon _unit,
      primaryWeaponItems _unit,
      handgunItems _unit,
      secondaryWeaponItems _unit,
      assignedItems _unit,
      uniformItems _unit,
      vestItems _unit,
      backpackItems _unit,
      magazinesAmmoFull _unit
    ]
  };

  OCAP_recorder_client_staminaFingerprint = {
    params ["_unit"];
    [loadAbs _unit, load _unit, [_unit] call OCAP_recorder_client_stanceCode]
  };

  OCAP_recorder_client_radioFingerprint = {
    params ["_unit"];
    private _fp = [];
    if (OCAP_recorder_client_hasTfar) then {
      private _activeSw = "";
      if (!isNil "TFAR_fnc_activeSwRadio") then {
        private _sw = call TFAR_fnc_activeSwRadio;
        if (!isNil "_sw" && {_sw isEqualType ""} && {_sw isNotEqualTo ""}) then {
          _activeSw = _sw;
        };
      };
      _fp pushBack _activeSw;

      private _swRadios = [];
      if (!isNil "TFAR_fnc_radiosList") then {
        _swRadios = _unit call TFAR_fnc_radiosList;
      };
      if (!(_swRadios isEqualType [])) then {_swRadios = []};
      if (_swRadios isEqualTo [] && {_activeSw isNotEqualTo ""}) then {
        _swRadios = [_activeSw];
      };
      {
        _fp pushBack _x;
        if (_x isEqualType "" && {_x isNotEqualTo ""} && {!isNil "TFAR_fnc_getSwChannel"}) then {
          private _channel = _x call TFAR_fnc_getSwChannel;
          _fp pushBack _channel;
          _fp pushBack ([_x, _channel + 1] call TFAR_fnc_getChannelFrequency);
          if (!isNil "TFAR_fnc_getAdditionalSwChannel") then {
            _fp pushBack (_x call TFAR_fnc_getAdditionalSwChannel);
          };
        };
      } forEach _swRadios;

      if (!isNil "TFAR_fnc_activeLrRadio") then {
        private _lr = call TFAR_fnc_activeLrRadio;
        _fp pushBack _lr;
        if (!isNil "_lr" && {_lr isEqualType []} && {count _lr >= 2}) then {
          private _channel = _lr call TFAR_fnc_getLrChannel;
          _fp pushBack _channel;
          _fp pushBack ([_lr, _channel + 1] call TFAR_fnc_getChannelFrequency);
          _fp pushBack (_lr call TFAR_fnc_getAdditionalLrChannel);
        };
      };
    };
    if (OCAP_recorder_client_hasAcre && {!isNil "acre_api_fnc_getCurrentRadioList"} && {
      isNil "acre_api_fnc_isInitialized" || {[] call acre_api_fnc_isInitialized}
    }) then {
      {
        private _radioId = _x;
        _fp pushBack _radioId;
        _fp pushBack ([_radioId] call acre_api_fnc_getRadioChannel);
        if (!isNil "acre_sys_data_fnc_dataEvent") then {
          private _channelData = [_radioId, "getCurrentChannelData"] call acre_sys_data_fnc_dataEvent;
          if (!isNil "_channelData" && {_channelData isEqualType locationNull} && {!isNull _channelData}) then {
            _fp pushBack (_channelData getVariable ["frequencyTX", 0]);
          };
        };
      } forEach (call acre_api_fnc_getCurrentRadioList);
    };
    _fp
  };

  // ACE broadcasts these with setVariable true, but the sampler still reads them
  // locally: a new bandage should show up in the activity log on the next PFH.
  // Unconscious / cardiac arrest / lifeState are here so a wake-up is not delayed
  // until the healthy medical interval elapses.
  OCAP_recorder_client_medicalFingerprint = {
    params ["_unit"];
    [
      lifeState _unit,
      _unit getVariable ["ACE_isUnconscious", false],
      _unit getVariable ["ace_medical_inCardiacArrest", false],
      _unit getVariable ["ace_medical_log_activity", []],
      _unit getVariable ["ace_medical_log_quick_view", []]
    ]
  };

  OCAP_recorder_client_playerTrackingLast = createHashMapFromArray [
    ["inventory", -1e10], ["medical", -1e10], ["stamina", -1e10], ["radio", -1e10]
  ];
  OCAP_recorder_client_playerTrackingFingerprint = createHashMap;
  OCAP_recorder_client_playerTrackingSession = -1;
  OCAP_recorder_client_playerTrackingUnit = objNull;
  OCAP_recorder_client_playerTrackingUnitId = -1;
  OCAP_recorder_client_radioSeen = false;

  // [kind, enable setting, fingerprint function], visited one per tick.
  OCAP_recorder_client_playerTrackingKinds = [
    ["inventory", QEGVAR(settings,trackPlayerInventory), OCAP_recorder_client_inventoryFingerprint],
    ["radio", QEGVAR(settings,trackPlayerRadio), OCAP_recorder_client_radioFingerprint],
    ["medical", QEGVAR(settings,trackPlayerMedical), OCAP_recorder_client_medicalFingerprint],
    ["stamina", QEGVAR(settings,trackPlayerStamina), OCAP_recorder_client_staminaFingerprint]
  ];
  OCAP_recorder_client_playerTrackingSlot = 0;

  // Every kind is still looked at every 5 seconds, as it always was, but the four
  // are visited one per 1.25 s tick instead of all in the same frame. Building
  // and sending an inventory, a radio, a medical and a stamina snapshot back to
  // back was a hitch on the client every five seconds, and the start of a
  // recording made every client do it at once and the server take four full
  // snapshots per player in one burst. A kind's worst-case delay is unchanged:
  // it is checked at most 5 s after it became due, exactly as before.
  OCAP_recorder_client_playerTrackingPFH = [{
    private _startTime = missionNamespace getVariable [QEGVAR(recorder,startTime), -1];
    private _isRecording = (missionNamespace getVariable [QEGVAR(recorder,recording), false]) && {_startTime > -1};
    if (!_isRecording || {isNull player}) exitWith {};
    // Death is captured by the killed EH (after the weapon drop). Keep the
    // periodic sampler off the corpse so it cannot outlive endFrame.
    if (!alive player) exitWith {};
    // The server stamps unitId from this variable. Sampling before it exists
    // would only be dropped, and must not consume the first-snapshot window.
    private _unitId = player getVariable [QGVARMAIN(id), -1];
    if (_unitId < 0) exitWith {};

    // New recordings, respawns and team switches need an initial snapshot even
    // when the new unit carries exactly the same kit. Keep the staggered turns.
    if (_startTime isNotEqualTo OCAP_recorder_client_playerTrackingSession ||
        {player isNotEqualTo OCAP_recorder_client_playerTrackingUnit} ||
        {_unitId isNotEqualTo OCAP_recorder_client_playerTrackingUnitId}) then {
      OCAP_recorder_client_playerTrackingSession = _startTime;
      OCAP_recorder_client_playerTrackingUnit = player;
      OCAP_recorder_client_playerTrackingUnitId = _unitId;
      {OCAP_recorder_client_playerTrackingLast set [_x, -1e10]} forEach (keys OCAP_recorder_client_playerTrackingLast);
      OCAP_recorder_client_playerTrackingFingerprint = createHashMap;
      OCAP_recorder_client_radioSeen = false;
    };

    (OCAP_recorder_client_playerTrackingKinds select OCAP_recorder_client_playerTrackingSlot) params ["_kind", "_setting", "_fingerprintFnc"];
    OCAP_recorder_client_playerTrackingSlot = (OCAP_recorder_client_playerTrackingSlot + 1) mod (count OCAP_recorder_client_playerTrackingKinds);

    if !(missionNamespace getVariable [_setting, true]) exitWith {};

    private _now = CBA_missionTime;
    private _interval = switch (_kind) do {
      case "inventory": {missionNamespace getVariable [QEGVAR(settings,playerInventoryInterval), 120]};
      case "radio": {missionNamespace getVariable [QEGVAR(settings,playerRadioInterval), 120]};
      case "stamina": {missionNamespace getVariable [QEGVAR(settings,playerStaminaInterval), 30]};
      case "medical": {
        if (OCAP_recorder_client_hasAceMedical && {
          (player getVariable ["ACE_isUnconscious", false]) || {player getVariable ["ace_medical_inCardiacArrest", false]}
        }) then {
          missionNamespace getVariable [QEGVAR(settings,playerMedicalCriticalInterval), 10]
        } else {
          missionNamespace getVariable [QEGVAR(settings,playerMedicalInterval), 60]
        }
      };
    };

    private _capture = false;
    if (_now - (OCAP_recorder_client_playerTrackingLast getOrDefault [_kind, -1e10]) >= _interval) then {
      _capture = true;
      OCAP_recorder_client_playerTrackingLast set [_kind, _now];
    };

    // Inventory, radio, stamina load and medical state sit unchanged for long
    // stretches, so the interval is only the worst-case gap. A loadout, frequency,
    // wake-up or carried-mass change is written on the kind's next turn as a
    // diff; the server drops the payload if it is still identical.
    if (_kind isNotEqualTo "radio" || {OCAP_recorder_client_hasTfar || OCAP_recorder_client_hasAcre}) then {
      private _fingerprint = [player] call _fingerprintFnc;
      if (_fingerprint isNotEqualTo (OCAP_recorder_client_playerTrackingFingerprint getOrDefault [_kind, []])) then {
        OCAP_recorder_client_playerTrackingFingerprint set [_kind, _fingerprint];
        _capture = true;
        OCAP_recorder_client_playerTrackingLast set [_kind, _now];
      };
    };

    if (_capture) then {
      ["periodic", [_kind], player] call OCAP_recorder_client_capturePlayerState;
    };
  }, 1.25] call CBA_fnc_addPerFrameHandler;

  // English Zeus-module labels. `getText` would freeze the Zeus client's
  // language into the recording; there is no SQF "localize as English". A
  // baked map covers ZEN / ACE / common vanilla classes, getTextRaw is used
  // when the config holds a literal, and unknown classes are split from the
  // classname the same way gear names are.
  OCAP_recorder_client_zeusModuleNames = createHashMapFromArray [
    ["zen_modules_moduleaddfullarsenal", "Add Full Arsenal"],
    ["zen_modules_moduleambientanim", "Ambient Animation"],
    ["zen_modules_moduleambientflyby", "Ambient Flyby"],
    ["zen_modules_moduleanimationviewer", "Animation Viewer"],
    ["zen_modules_modulearsenal", "Arsenal"],
    ["zen_modules_moduleassignzeus", "Promote To Zeus"],
    ["zen_modules_moduleattacheffect", "Attach/Detach Effect"],
    ["zen_modules_moduleattachflag", "Attach Flag"],
    ["zen_modules_modulebindvariable", "Bind Variable To Object"],
    ["zen_modules_modulecasgun", "CAS Gun"],
    ["zen_modules_modulecasmissile", "CAS Missiles"],
    ["zen_modules_modulecasgunmissile", "CAS Gun and Missiles"],
    ["zen_modules_modulecasbomb", "CAS Bomb"],
    ["zen_modules_modulechangeheight", "Change Height"],
    ["zen_modules_modulechatter", "Chatter"],
    ["zen_modules_moduleconvoyparameters", "Convoy Parameters"],
    ["zen_modules_modulecreateied", "Create IED"],
    ["zen_modules_modulecreateintel", "Create/Edit Intel"],
    ["zen_modules_modulecreatelz", "Create LZ"],
    ["zen_modules_modulecreateminefield", "Create Minefield"],
    ["zen_modules_modulecreaterp", "Create RP"],
    ["zen_modules_modulecreatetarget", "Create Target"],
    ["zen_modules_modulecreateteleporter", "Create Teleporter"],
    ["zen_modules_modulecrewtogunner", "Crew To Gunner"],
    ["zen_modules_moduledamagebuildings", "Damage Buildings"],
    ["zen_modules_moduleearthquake", "Earthquake"],
    ["zen_modules_moduleeditableobjects", "Update Editable Objects"],
    ["zen_modules_moduleeffectfire", "Custom Fire"],
    ["zen_modules_moduleequipwithecm", "Equip With ECM"],
    ["zen_modules_moduleexportmissionsqf", "Export Mission SQF"],
    ["zen_modules_moduleexecutecode", "Execute Code"],
    ["zen_modules_modulefiremission", "Artillery Fire Mission"],
    ["zen_modules_moduleflyheight", "Fly Height"],
    ["zen_modules_modulefunctionsviewer", "Functions Viewer"],
    ["zen_modules_modulegarrison", "Garrison Group"],
    ["zen_modules_moduleglobalaiskill", "Global AI Skill"],
    ["zen_modules_moduleglobalhint", "Global Hint"],
    ["zen_modules_modulegroupside", "Group Side"],
    ["zen_modules_moduleheal", "Heal"],
    ["zen_modules_modulehideterrainobjects", "Hide Terrain Objects"],
    ["zen_modules_modulehidezeus", "Hide Zeus"],
    ["zen_modules_modulelightsource", "Light Source"],
    ["zen_modules_modulemakeinvincible", "Make Invincible"],
    ["zen_modules_modulenuke", "Atomic Bomb"],
    ["zen_modules_modulepatrolarea", "Patrol Area"],
    ["zen_modules_moduleremovearsenal", "Remove Arsenal"],
    ["zen_modules_modulerotateobject", "Rotate Object"],
    ["zen_modules_modulescaleobject", "Scale Object"],
    ["zen_modules_modulesearchbuilding", "Search Building"],
    ["zen_modules_modulesetdate", "Set Date"],
    ["zen_modules_moduleshowinconfig", "Show In Config Viewer"],
    ["zen_modules_modulesiderelations", "Side Relations"],
    ["zen_modules_modulesimulation", "Toggle Simulation"],
    ["zen_modules_modulesitonchair", "Sit On Chair"],
    ["zen_modules_modulesmokepillar", "Smoke Pillar"],
    ["zen_modules_modulespawncarrier", "USS Freedom"],
    ["zen_modules_modulespawndestroyer", "USS Liberty"],
    ["zen_modules_modulespawnreinforcements", "Spawn Reinforcements"],
    ["zen_modules_modulesuicidebomber", "Suicide Bomber"],
    ["zen_modules_modulesuppressivefire", "Suppressive Fire"],
    ["zen_modules_moduleteleportplayers", "Teleport Players"],
    ["zen_modules_moduletoggleflashlights", "Toggle Flashlights"],
    ["zen_modules_moduletoggleirlasers", "Toggle IR Lasers"],
    ["zen_modules_moduletogglelamps", "Toggle Lamps"],
    ["zen_modules_moduletracers", "Tracers"],
    ["zen_modules_moduleturretoptics", "Vehicle Turret Optics"],
    ["zen_modules_moduleungarrison", "Un-Garrison Group"],
    ["zen_modules_modulevisibility", "Toggle Visibility"],
    ["zen_modules_moduleweather", "Change Weather"],
    ["zen_remote_control_module", "Remote Control"],
    ["zen_doors_module", "Configure Doors"],
    ["zen_cover_map_module", "Cover Map"],
    ["zen_attached_objects_module", "Attach To"],
    ["zen_tasks_module", "Task"],
    ["ace_zeus_moduleaddsparetrack", "Add Spare Track"],
    ["ace_zeus_moduleaddsparewheel", "Add Spare Wheel"],
    ["ace_zeus_modulesetengineer", "Set Engineer"],
    ["ace_zeus_modulesetrepairfacility", "Set Repair Facility"],
    ["ace_zeus_modulesetrepairvehicle", "Set Repair Vehicle"],
    ["ace_zeus_moduleaddorremovefries", "Add/Remove FRIES"],
    ["ace_zeus_modulecaptive", "Captive"],
    ["ace_zeus_moduleconfigurepylons", "Configure Pylons"],
    ["ace_zeus_moduledefendarea", "Defend Area"],
    ["ace_zeus_moduleeditableobjects", "Editable Objects"],
    ["ace_zeus_moduleglobalsetskill", "Global AI Skill"],
    ["ace_zeus_modulegroupside", "Group Side"],
    ["ace_zeus_moduleheal", "Heal"],
    ["ace_zeus_modulelaytrench", "Lay Trench"],
    ["ace_zeus_moduleloadintocargo", "Load Into Cargo"],
    ["ace_zeus_moduleunloadfromcargo", "Unload From Cargo"],
    ["ace_zeus_modulecargoparadrop", "Cargo Paradrop"],
    ["ace_zeus_modulepatrolarea", "Patrol Area"],
    ["ace_zeus_modulesearcharea", "Search Area"],
    ["ace_zeus_modulesearchnearby", "Search Nearby"],
    ["ace_zeus_modulesuppressivefire", "Suppressive Fire"],
    ["ace_zeus_modulesetmedic", "Set Medic"],
    ["ace_zeus_modulesetmedicalfacility", "Set Medical Facility"],
    ["ace_zeus_modulesetmedicalvehicle", "Set Medical Vehicle"],
    ["ace_zeus_modulesimulation", "Toggle Simulation"],
    ["ace_zeus_modulespectator", "Spectator"],
    ["ace_zeus_modulesuicidebomber", "Suicide Bomber"],
    ["ace_zeus_modulesurrender", "Surrender"],
    ["ace_zeus_moduleteleportplayers", "Teleport Players"],
    ["ace_zeus_moduleunconscious", "Unconscious"],
    ["ace_zeus_modulegarrison", "Garrison"],
    ["ace_zeus_moduleungarrison", "Un-Garrison"],
    ["ace_zeus_moduletogglenvg", "Toggle NVG"],
    ["ace_zeus_moduletoggleflashlight", "Toggle Flashlight"],
    ["ace_zeus_addfullarsenal", "Add Full Arsenal"],
    ["ace_zeus_removefullarsenal", "Remove Arsenal"],
    ["ace_zeus_addfullacearsenal", "Add Full ACE Arsenal"],
    ["ace_zeus_removefullacearsenal", "Remove ACE Arsenal"],
    ["ace_zeus_moduleburn", "Burn"],
    ["ace_zeus_modulemedicalmenu", "Medical Menu"],
    ["modulelightning_f", "Lightning Bolt"],
    ["modulecas_f", "CAS"],
    ["modulecasgun_f", "CAS Gun"],
    ["modulecasmissile_f", "CAS Missiles"],
    ["modulecasgunmissile_f", "CAS Gun and Missiles"],
    ["modulecasbomb_f", "CAS Bomb"],
    ["modulearsenal_f", "Arsenal"],
    ["moduleremotecontrol_f", "Remote Control"],
    ["moduletracers_f", "Tracers"],
    ["modulepostprocess_f", "Postprocess"],
    ["moduleskiptime_f", "Skip Time"],
    ["moduleweather_f", "Weather"],
    ["moduleflare_f", "Flare"],
    ["modulechemlight_f", "Chemlight"],
    ["moduleordnance_f", "Ordnance"],
    ["moduleordnancehowitzer_f", "Howitzer"],
    ["moduleordnancemortar_f", "Mortar"],
    ["moduleordnancerocket_f", "Rocket"],
    ["modulemine_f", "Mine"],
    ["modulecovermap_f", "Cover Map"],
    ["moduleobjective_f", "Objective"],
    ["moduleobjectivemove_f", "Move"],
    ["moduleobjectivesector_f", "Sector"],
    ["moduleobjectiveattackdefend_f", "Attack / Defend"],
    ["moduleobjectiveneutralize_f", "Neutralize"],
    ["moduleobjectiveprotect_f", "Protect"],
    ["moduleobjectivegetin_f", "Get In"],
    ["moduleobjectiveracestart_f", "Race Start"],
    ["moduleobjectiveracecp_f", "Race Checkpoint"],
    ["moduleobjectiveracefinish_f", "Race Finish"],
    ["modulecuratoraddaddons_f", "Add Addons"],
    ["modulecuratoraddeditableobjects_f", "Add Editable Objects"],
    ["modulecuratorsetcamera_f", "Set Camera"]
  ];
  OCAP_recorder_client_zeusModuleCategories = createHashMapFromArray [
    ["zen_modules_ai", "AI"],
    ["zen_modules_buildings", "Buildings"],
    ["zen_modules_devtools", "Dev Tools"],
    ["zen_modules_equipment", "Equipment"],
    ["zen_modules_inventory", "Inventory"],
    ["zen_modules_objects", "Objects"],
    ["zen_modules_players", "Players"],
    ["zen_modules_reinforcements", "Reinforcements"],
    ["zen_modules_spawn", "Spawn"],
    ["ace_zeus_repair", "Repair"],
    ["ace_zeus_captive", "Captive"],
    ["ace_zeus_utility", "Utility"],
    ["ace_zeus_ai", "AI"],
    ["ace_zeus_medical", "Medical"],
    ["ace_zeus_arsenal", "Arsenal"],
    ["curator", "Zeus"],
    ["ordnance", "Ordnance"],
    ["environment", "Environment"],
    ["effects", "Effects"],
    ["missionflow", "Mission Flow"],
    ["objectives", "Objectives"],
    ["ace", "ACE"],
    ["chemlights", "Chemlights"]
  ];
  OCAP_recorder_client_zeusModulePrefixes = [
    "zen_custom_modules_",
    "zen_modules_module",
    "zen_modules_",
    "zen_remote_control_",
    "zen_doors_",
    "zen_cover_map_",
    "zen_attached_objects_",
    "zen_tasks_",
    "ace_zeus_module",
    "ace_zeus_"
  ];
  OCAP_recorder_client_zeusModuleAcronyms = [
    "cas", "ied", "lz", "rp", "ecm", "sqf", "ir", "nvg", "ai", "fries", "uss", "hq", "gps", "ace"
  ];

  OCAP_recorder_client_isEnglishText = {
    params [["_text", "", [""]]];
    if (_text isEqualTo "") exitWith {false};
    private _ok = true;
    {
      private _pass = _x == 32 || {_x == 45} || {_x == 47} || {_x == 38} || {_x == 39} || {_x == 40} || {_x == 41} || {_x == 43} || {_x == 44} || {_x == 46} || {_x >= 48 && _x <= 57} || {_x >= 65 && _x <= 90} || {_x >= 97 && _x <= 122};
      if (!_pass) then {_ok = false};
    } forEach toArray _text;
    _ok && {((toUpper _text) select [0, 4]) isNotEqualTo "STR_"}
  };

  OCAP_recorder_client_humanizeZeusModuleClass = {
    params [["_className", "", [""]]];
    if (_className isEqualTo "") exitWith {""};

    private _base = _className;
    private _lower = toLower _base;
    {
      if ((_lower find _x) == 0 && {count _base > count _x}) exitWith {
        _base = _base select [count _x];
        _lower = toLower _base;
      };
    } forEach OCAP_recorder_client_zeusModulePrefixes;

    if ((_lower select [count _lower - 2, 2]) isEqualTo "_f") then {
      _base = _base select [0, count _base - 2];
      _lower = toLower _base;
    };
    if ((_lower select [0, 6]) isEqualTo "module" && {count _base > 6}) then {
      _base = _base select [6];
    };

    private _name = [_base] call OCAP_recorder_client_deriveNameFromClass;
    if (_name isEqualTo "" || {_name isEqualTo _base && {_base regexMatch "^\d+$"}}) then {
      _name = "Custom Module";
    };
    (_name splitString " " apply {
      if ((toLower _x) in OCAP_recorder_client_zeusModuleAcronyms) then {toUpper _x} else {_x}
    }) joinString " "
  };

  OCAP_recorder_client_zeusModuleDisplayName = {
    params ["_object", ["_className", "", [""]]];
    if (_className isEqualTo "") then {_className = typeOf _object};

    private _cached = OCAP_recorder_client_zeusModuleNames get toLower _className;
    if (!isNil "_cached") exitWith {_cached};

    if (((toLower _className) find "zen_custom_modules_") == 0) exitWith {
      private _index = getNumber (configOf _object >> "zen_custom_modules_id") - 1;
      private _entry = missionNamespace getVariable ["zen_custom_modules_list", []] param [_index, []];
      private _customName = _entry param [1, ""];
      if ([_customName] call OCAP_recorder_client_isEnglishText) then {_customName} else {"Custom Module"}
    };

    private _raw = getTextRaw (configOf _object >> "displayName");
    if (_raw isEqualType []) then {_raw = _raw param [0, ""]};
    if (!(_raw isEqualType "")) then {_raw = ""};
    _raw = trim _raw;
    if (_raw isNotEqualTo "" && {(_raw select [0, 1]) isNotEqualTo "$"} && {[_raw] call OCAP_recorder_client_isEnglishText}) then {
      _raw
    } else {
      [_className] call OCAP_recorder_client_humanizeZeusModuleClass
    }
  };

  OCAP_recorder_client_zeusModuleCategory = {
    params ["_object"];
    private _raw = getTextRaw (configOf _object >> "category");
    if (_raw isEqualType []) then {_raw = _raw param [0, ""]};
    if (!(_raw isEqualType "")) then {_raw = ""};
    if (_raw isEqualTo "" || {_raw isEqualTo "NO_CATEGORY"}) exitWith {""};
    private _mapped = OCAP_recorder_client_zeusModuleCategories get toLower _raw;
    if (!isNil "_mapped") exitWith {_mapped};
    if ([_raw] call OCAP_recorder_client_isEnglishText && {(_raw select [0, 1]) isNotEqualTo "$"}) exitWith {_raw};
    [_raw] call OCAP_recorder_client_humanizeZeusModuleClass
  };

  OCAP_recorder_client_zeusModuleSource = {
    params [["_className", "", [""]]];
    private _lower = toLower _className;
    if ((_lower select [0, 20]) isEqualTo "zen_custom_modules_") exitWith {"zenCustom"};
    if ((_lower select [0, 4]) isEqualTo "zen_") exitWith {"zen"};
    if ((_lower select [0, 9]) isEqualTo "ace_zeus_") exitWith {"ace"};
    if ((_lower select [0, 6]) isEqualTo "module") exitWith {"vanilla"};
    "other"
  };

  OCAP_recorder_client_reportZeusModule = {
    params ["_curator", "_object"];
    if (isNull _object) exitWith {};
    if !(_object isKindOf "Module_F") exitWith {};
    if (typeOf _object isEqualTo "ModuleCurator_F") exitWith {};
    if !(missionNamespace getVariable [QEGVAR(settings,trackZeus), true]) exitWith {};
    if !(missionNamespace getVariable [QEGVAR(settings,trackZeusModules), true]) exitWith {};

    private _className = typeOf _object;
    private _pos = getPosATL _object;
    private _attached = attachedTo _object;
    if (isNull _attached) then {
      curatorMouseOver params ["_kind", "_entity"];
      if (_kind isEqualTo "OBJECT") then {_attached = _entity};
    };

    private _attachedName = "";
    if (!isNull _attached) then {
      if (_attached isKindOf "CAManBase") then {
        _attachedName = name _attached;
      } else {
        _attachedName = [typeOf _attached] call OCAP_recorder_client_gearDisplayName;
      };
    };

    [
      getAssignedCuratorUnit _curator,
      _attached,
      createHashMapFromArray [
        ["className", _className],
        ["displayName", [_object, _className] call OCAP_recorder_client_zeusModuleDisplayName],
        ["category", [_object] call OCAP_recorder_client_zeusModuleCategory],
        ["source", [_className] call OCAP_recorder_client_zeusModuleSource],
        ["x", _pos select 0],
        ["y", _pos select 1],
        ["attachedName", _attachedName]
      ]
    ] remoteExecCall [QFUNC(submitZeusModule), 2];
  };

  // curatorCamera exists only on the Zeus client. The player-detail PFH above
  // also exits when the body has no OCAP id, which is the normal case for a
  // virtual curator slot — this sampler must stay independent of that.
  if (isNil "OCAP_recorder_client_zeusCameraPFH") then {
    OCAP_recorder_client_zeusCameraLast = -1e10;
    OCAP_recorder_client_zeusCameraSent = [];
    OCAP_recorder_client_zeusCameraSentAt = -1e10;
    OCAP_recorder_client_zeusCameraSession = -1;
    OCAP_recorder_client_zeusPingedLogics = [];
    OCAP_recorder_client_zeusCameraPFH = [{
      if (isNull player) exitWith {};

      // CuratorPinged only ever fires where the curator logic is local, which is
      // the Zeus's own machine — the server never sees it. Attach once per logic:
      // assignment can happen long after the bootstrap ran, and this must not sit
      // behind the recording or curatorCamera guards below, because a Zeus with the
      // interface closed still receives pings.
      private _logic = getAssignedCuratorLogic player;
      if (!isNull _logic && {!(_logic in OCAP_recorder_client_zeusPingedLogics)}) then {
        OCAP_recorder_client_zeusPingedLogics pushBack _logic;
        _logic addEventHandler ["CuratorPinged", {
          params ["_curator", "_pinger"];
          if (isNull _pinger) exitWith {};
          if !(missionNamespace getVariable [QEGVAR(settings,trackZeus), true]) exitWith {};
          if !(missionNamespace getVariable [QEGVAR(settings,trackZeusPings), true]) exitWith {};
          [getAssignedCuratorUnit _curator, _pinger] remoteExecCall [QFUNC(submitZeusPing), 2];
        }];
        // Same locality as pings: the dedicated server never sees this.
        _logic addEventHandler ["CuratorObjectPlaced", {
          _this call OCAP_recorder_client_reportZeusModule;
        }];
      };

      private _startTime = missionNamespace getVariable [QEGVAR(recorder,startTime), -1];
      private _isRecording = (missionNamespace getVariable [QEGVAR(recorder,recording), false]) && {_startTime > -1};
      if (!_isRecording) exitWith {};
      if !(missionNamespace getVariable [QEGVAR(settings,trackZeus), true]) exitWith {};
      if (isNull curatorCamera) exitWith {};
      if (isNull _logic) exitWith {};

      private _now = CBA_missionTime;
      private _interval = missionNamespace getVariable [QEGVAR(settings,zeusCameraInterval), 1];
      if (_now - OCAP_recorder_client_zeusCameraLast < _interval) exitWith {};
      OCAP_recorder_client_zeusCameraLast = _now;

      private _pos = getPosASL curatorCamera;
      private _dir = getDir curatorCamera;
      private _fov = getObjectFOV curatorCamera;
      private _pitch = (vectorDir curatorCamera) select 2;

      // The server keeps a camera sample only when it differs from the last one
      // after this exact rounding (OCAP_recorder_fnc_submitZeusCamera), so a
      // parked camera used to cost one network message a second for nothing --
      // on the client that already sends the most traffic. Skip those here.
      // A new recording resets the server's copy, so it resets this one too; the
      // periodic resend only bounds how long the two could ever disagree, and the
      // server still drops it if nothing moved.
      if (_startTime isNotEqualTo OCAP_recorder_client_zeusCameraSession) then {
        OCAP_recorder_client_zeusCameraSession = _startTime;
        OCAP_recorder_client_zeusCameraSent = [];
      };
      private _rounded = [round (_pos select 0), round (_pos select 1), round _dir, parseNumber (_fov toFixed 3), parseNumber (_pitch toFixed 2)];
      if (_rounded isEqualTo OCAP_recorder_client_zeusCameraSent && {_now - OCAP_recorder_client_zeusCameraSentAt < 30}) exitWith {};
      OCAP_recorder_client_zeusCameraSent = _rounded;
      OCAP_recorder_client_zeusCameraSentAt = _now;

      [player, createHashMapFromArray [
        ["x", _pos select 0],
        ["y", _pos select 1],
        ["dir", _dir],
        ["fov", _fov],
        ["pitch", _pitch]
      ]] remoteExecCall [QFUNC(submitZeusCamera), 2];
    }, 0.25] call CBA_fnc_addPerFrameHandler;
  };

  // Static weapons. Both signals are local to the machine that builds the gun,
  // and neither is visible to the server:
  //
  //   - "WeaponAssembled" and "WeaponDisassembled" are unit event handlers that
  //     fire only where the unit is local. The server registers the same pair
  //     for its own AI in <OCAP_recorder_fnc_addUnitEventHandlers>.
  //   - ACE3 CSW never uses the engine command. It builds the gun with
  //     createVehicle and raises ace_csw_deployWeaponSucceeded as a *local*
  //     event on the deploying client, so the local player is the builder.
  //
  // The handlers are re-attached whenever the player's unit changes, which
  // covers respawn and team switch; CBA_fnc_addPlayerEventHandler also runs it
  // once for the unit the player already has.
  if (isNil "OCAP_recorder_client_staticWeaponInit") then {
    OCAP_recorder_client_staticWeaponInit = true;

    ["unit", {
      params ["_unit"];
      if (isNull _unit) exitWith {};
      if (!isNil {_unit getVariable "OCAP_recorder_client_staticWeaponEH"}) exitWith {};

      _unit setVariable ["OCAP_recorder_client_staticWeaponEH", _unit addEventHandler ["WeaponAssembled", {
        params ["_unit", "_static"];
        if (!(missionNamespace getVariable [QEGVAR(settings,trackConstructions), true])) exitWith {};
        ["assembled", _unit, _static] remoteExecCall [QFUNC(submitStaticWeapon), 2];
      }]];

      // WeaponDisassembled carries the two bags, not the gun, and the gun is
      // already deleted -- the server turns this into a claim and matches it
      // against whichever gun actually disappears.
      _unit addEventHandler ["WeaponDisassembled", {
        params ["_unit"];
        if (!(missionNamespace getVariable [QEGVAR(settings,trackConstructions), true])) exitWith {};
        ["disassembled", _unit, objNull] remoteExecCall [QFUNC(submitStaticWeapon), 2];
      }];
    }, true] call CBA_fnc_addPlayerEventHandler;

    if (isClass (configFile >> "CfgPatches" >> "ace_csw")) then {
      ["ace_csw_deployWeaponSucceeded", {
        params ["_csw"];
        if (isNull _csw) exitWith {};
        if (!(missionNamespace getVariable [QEGVAR(settings,trackConstructions), true])) exitWith {};
        ["assembled", player, _csw] remoteExecCall [QFUNC(submitStaticWeapon), 2];
      }] call CBA_fnc_addEventHandler;
    };
  };
} remoteExec ["call", [0, -2] select isDedicated, QGVAR(playerTrackingBootstrapJip)];
