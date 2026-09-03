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
    QEGVAR(settings,trackPlayerMedical),
    QEGVAR(settings,playerMedicalInterval),
    QEGVAR(settings,playerMedicalCriticalInterval),
    QEGVAR(settings,trackPlayerStamina),
    QEGVAR(settings,playerStaminaInterval),
    QEGVAR(settings,trackPlayerRadio),
    QEGVAR(settings,playerRadioInterval),
    QEGVAR(settings,trackPlayerSnapshotDiffs),
    QEGVAR(settings,radioShortRangeMeters),
    QEGVAR(settings,radioLongRangeMeters)
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
    if (_base regexMatch "Item[A-Z].*") then {_base = _base select [4]};

    // Split on separators and at every lowercase-to-uppercase step, but never
    // between a digit and a letter, so L85A2 stays a single word.
    private _words = [];
    private _word = "";
    {
      private _char = toString [_x];
      if (_char in ["_", " ", "-"]) then {
        if (_word isNotEqualTo "") then {_words pushBack _word; _word = ""};
      } else {
        if (_word isNotEqualTo "" && {_char regexMatch "[A-Z]"} &&
          {(_word select [count _word - 1]) regexMatch "[a-z]"}) then {
          _words pushBack _word;
          _word = "";
        };
        _word = _word + _char;
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
      private _result = [];
      {
        private _className = _x;
        private _entry = [createHashMapFromArray [
          ["class", _className],
          ["count", {_x isEqualTo _className} count _items]
        ], _className] call OCAP_recorder_client_setDisplayName;
        if (_withCategory) then {
          private _category = [_className] call OCAP_recorder_client_getItemCategory;
          if (_category isNotEqualTo "items") then {_entry set ["cat", _category]};
        };
        _result pushBack _entry;
      } forEach (_items arrayIntersect _items);
      _result
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

    // magazinesAmmoFull entries are [class, ammoCount, isLoaded, ...].
    private _magazinesFull = magazinesAmmoFull _unit;
    private _magazines = [];
    private _magazineClasses = (_magazinesFull apply {_x param [0, ""]}) select {_x isNotEqualTo ""};
    {
      private _className = _x;
      private _matching = _magazinesFull select {(_x param [0, ""]) isEqualTo _className};
      private _totalRounds = 0;
      {_totalRounds = _totalRounds + (_x param [1, 0])} forEach _matching;
      private _entry = createHashMapFromArray [
        ["class", _className],
        ["count", count _matching],
        ["totalRounds", _totalRounds],
        ["loadedCount", {_x param [2, false]} count _matching]
      ];
      [_entry, _className] call OCAP_recorder_client_setDisplayName;
      private _category = [_className] call OCAP_recorder_client_getItemCategory;
      if (_category isNotEqualTo "items") then {_entry set ["cat", _category]};
      _magazines pushBack _entry;
    } forEach (_magazineClasses arrayIntersect _magazineClasses);

    createHashMapFromArray [
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
    ]
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
        ["massUnits", loadAbs _unit]
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
    [
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
    [loadAbs _unit, load _unit]
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
  OCAP_recorder_client_radioSeen = false;

  OCAP_recorder_client_playerTrackingPFH = [{
    private _startTime = missionNamespace getVariable [QEGVAR(recorder,startTime), -1];
    private _isRecording = (missionNamespace getVariable [QEGVAR(recorder,recording), false]) && {_startTime > -1};
    if (!_isRecording || {isNull player}) exitWith {};
    // Death is captured by the killed EH (after the weapon drop). Keep the
    // periodic sampler off the corpse so it cannot outlive endFrame.
    if (!alive player) exitWith {};
    // The server stamps unitId from this variable. Sampling before it exists
    // would only be dropped, and must not consume the first-snapshot window.
    if ((player getVariable [QGVARMAIN(id), -1]) < 0) exitWith {};

    // A new recording starts a new snapshot chain, so every tracker samples again at once.
    if (_startTime isNotEqualTo OCAP_recorder_client_playerTrackingSession) then {
      OCAP_recorder_client_playerTrackingSession = _startTime;
      {OCAP_recorder_client_playerTrackingLast set [_x, -1e10]} forEach (keys OCAP_recorder_client_playerTrackingLast);
      OCAP_recorder_client_playerTrackingFingerprint = createHashMap;
      OCAP_recorder_client_radioSeen = false;
    };

    private _now = CBA_missionTime;
    private _medicalInterval = missionNamespace getVariable [QEGVAR(settings,playerMedicalInterval), 60];
    if (OCAP_recorder_client_hasAceMedical && {
      (player getVariable ["ACE_isUnconscious", false]) || {player getVariable ["ace_medical_inCardiacArrest", false]}
    }) then {
      _medicalInterval = missionNamespace getVariable [QEGVAR(settings,playerMedicalCriticalInterval), 10];
    };

    private _kinds = [];
    {
      _x params ["_kind", "_setting", "_interval"];
      if (missionNamespace getVariable [_setting, true] &&
        {_now - (OCAP_recorder_client_playerTrackingLast getOrDefault [_kind, -1e10]) >= _interval}) then {
        _kinds pushBackUnique _kind;
        OCAP_recorder_client_playerTrackingLast set [_kind, _now];
      };
    } forEach [
      ["inventory", QEGVAR(settings,trackPlayerInventory), missionNamespace getVariable [QEGVAR(settings,playerInventoryInterval), 120]],
      ["medical", QEGVAR(settings,trackPlayerMedical), _medicalInterval],
      ["stamina", QEGVAR(settings,trackPlayerStamina), missionNamespace getVariable [QEGVAR(settings,playerStaminaInterval), 30]],
      ["radio", QEGVAR(settings,trackPlayerRadio), missionNamespace getVariable [QEGVAR(settings,playerRadioInterval), 120]]
    ];

    // Inventory, radio, stamina load and medical state sit unchanged for long
    // stretches, so the interval is only the worst-case gap. A loadout, frequency,
    // wake-up or carried-mass change is written immediately as a diff; the server
    // drops the payload if it is still identical.
    {
      _x params ["_kind", "_setting", "_fingerprintFnc"];
      if !(missionNamespace getVariable [_setting, true]) then {continue};
      if (_kind isEqualTo "radio" && {!OCAP_recorder_client_hasTfar && !OCAP_recorder_client_hasAcre}) then {continue};
      private _fingerprint = [player] call _fingerprintFnc;
      if (_fingerprint isNotEqualTo (OCAP_recorder_client_playerTrackingFingerprint getOrDefault [_kind, []])) then {
        OCAP_recorder_client_playerTrackingFingerprint set [_kind, _fingerprint];
        _kinds pushBackUnique _kind;
        OCAP_recorder_client_playerTrackingLast set [_kind, _now];
      };
    } forEach [
      ["inventory", QEGVAR(settings,trackPlayerInventory), OCAP_recorder_client_inventoryFingerprint],
      ["radio", QEGVAR(settings,trackPlayerRadio), OCAP_recorder_client_radioFingerprint],
      ["medical", QEGVAR(settings,trackPlayerMedical), OCAP_recorder_client_medicalFingerprint],
      ["stamina", QEGVAR(settings,trackPlayerStamina), OCAP_recorder_client_staminaFingerprint]
    ];

    if (_kinds isNotEqualTo []) then {
      ["periodic", _kinds, player] call OCAP_recorder_client_capturePlayerState;
    };
  }, 5] call CBA_fnc_addPerFrameHandler;
} remoteExec ["call", [0, -2] select isDedicated, QGVAR(playerTrackingBootstrapJip)];
