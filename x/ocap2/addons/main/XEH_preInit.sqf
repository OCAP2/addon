#include "script_component.hpp"
#include "XEH_prep.sqf"

// AUTO START SETTINGS
[
  QEGVAR(settings,autoStart),
  "CHECKBOX", // setting type
  [
    "Auto Start Recording", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    "Automatically start OCAP recordings at session start. Default: true"
  ],
  [COMPONENT_NAME, "Auto-start Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
  true, // default enabled
  true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
  {}, // function that will be executed once on mission start and every time the setting is changed.
  true // requires restart to apply
] call CBA_fnc_addSetting;

[
  QEGVAR(settings,minPlayerCount),
  "SLIDER", // setting type
  [
    "Minimum Player Count", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    "Auto-start will begin once this player count is reached. Default: 15"
  ],
  [COMPONENT_NAME, "Auto-start Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
  [
      1, // min
      150, // max
      15, // default
      0, // trailing decimals
      false // percentage
  ], // data for this setting: [min, max, default, number of shown trailing decimals]
  true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
  {}, // function that will be executed once on mission start and every time the setting is changed.
  true // requires restart to apply
] call CBA_fnc_addSetting;



// RECORDING SETTINGS
[
  QEGVAR(settings,frameCaptureDelay),
  "SLIDER", // setting type
  [
    "Frame Capture Delay", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    "Positioning, medical status, and crew states of units and vehicles will be captured every X amount of seconds. Default: 1"
  ],
  [COMPONENT_NAME, "Recording Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
  [
      0.25, // min
      10, // max
      1, // default
      0, // trailing decimals
      false // percentage
  ], // data for this setting: [min, max, default, number of shown trailing decimals]
  true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
  {}, // function that will be executed once on mission start and every time the setting is changed.
  false // requires restart to apply
] call CBA_fnc_addSetting;

[
  QEGVAR(settings,minMissionTime),
  "SLIDER", // setting type
  [
    "Required Duration to Save", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    "A recording must be at least this long (in minutes) to save. Default: 20"
  ],
  [COMPONENT_NAME, "Recording Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
  [
      1, // min
      120, // max
      20, // default
      0, // trailing decimals
      false // percentage
  ], // data for this setting: [min, max, default, number of shown trailing decimals]
  true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
  {}, // function that will be executed once on mission start and every time the setting is changed.
  false // requires restart to apply
] call CBA_fnc_addSetting;

[
  QEGVAR(settings,preferACEUnconscious),
  "CHECKBOX", // setting type
  [
    "Use ACE3 Medical", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    "If true, will check ACE3 medical status on units. If false, or ACE3 isn't loaded, fall back to vanilla. Default: true"
  ],
  [COMPONENT_NAME, "Recording Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
  true, // default enabled
  true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
  {}, // function that will be executed once on mission start and every time the setting is changed.
  false // requires restart to apply
] call CBA_fnc_addSetting;

[
  QEGVAR(settings,excludeClassFromRecord),
  "EDITBOX", // setting type
  [
    "Classnames to Exclude", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    "Array of object classnames that should be excluded from recording. Use single quotes! Default: ['ACE_friesAnchorBar', 'GroundWeaponHolder', 'WeaponHolderSimulated']"
  ],
  [COMPONENT_NAME, "Recording Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
  "['ACE_friesAnchorBar', 'GroundWeaponHolder', 'WeaponHolderSimulated']", // default string value
  true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
  {}, // function that will be executed once on mission start and every time the setting is changed.
  false // requires restart to apply
] call CBA_fnc_addSetting;

[
  QEGVAR(settings,excludeKindFromRecord),
  "EDITBOX", // setting type
  [
    "Object KindOfs to Exclude", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    "Array of classnames which, along with all child classes, should be excluded from recording. Use single quotes! Default: []"
  ],
  [COMPONENT_NAME, "Recording Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
  "[]", // default string value
  true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
  {}, // function that will be executed once on mission start and every time the setting is changed.
  false // requires restart to apply
] call CBA_fnc_addSetting;

[
  QEGVAR(settings,excludeMarkerFromRecord),
  "EDITBOX", // setting type
  [
    "Marker Prefixes to Exclude", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    "Array of prefixes - any markers matching these prefixes will be excluded from recording. Use single quotes! Default: ['SystemMarker_']"
  ],
  [COMPONENT_NAME, "Recording Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
  "['SystemMarker_']", // default string value
  true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
  {}, // function that will be executed once on mission start and every time the setting is changed.
  false // requires restart to apply
] call CBA_fnc_addSetting;

[
  QEGVAR(settings,trackTimes),
  "CHECKBOX", // setting type
  [
    "Enable Mission Time Tracking", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    "Will continuously track in-game world time during a mission. Useful for accelerated/skipped time scenarios. Default: false"
  ],
  [COMPONENT_NAME, "Recording Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
  false, // default enabled
  true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
  {}, // function that will be executed once on mission start and every time the setting is changed.
  false // requires restart to apply
] call CBA_fnc_addSetting;

[
  QEGVAR(settings,trackTimeInterval),
  "SLIDER", // setting type
  [
    "Mission Time Tracking Interval", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    "If time tracking is enabled, it will be checked every X capture frames. Default: 10"
  ],
  [COMPONENT_NAME, "Recording Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
  [
      5, // min
      25, // max
      10, // default
      0, // trailing decimals
      false // percentage
  ], // data for this setting: [min, max, default, number of shown trailing decimals]
  true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
  {}, // function that will be executed once on mission start and every time the setting is changed.
  false // requires restart to apply
] call CBA_fnc_addSetting;



// SAVING SETTINGS
[
  QEGVAR(settings,saveMissionEnded),
  "CHECKBOX", // setting type
  [
    "Auto-save on MPEnded Event", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    "If true, automatically save and export the mission when the MPEnded event fires. Default: true"
  ],
  [COMPONENT_NAME, "Save/Export Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
  true, // default enabled
  true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
  {}, // function that will be executed once on mission start and every time the setting is changed.
  true // requires restart to apply
] call CBA_fnc_addSetting;



// DEBUG
[
  QGVARMAIN(enabled),
  "CHECKBOX", // setting type
  [
    "Recording Enabled", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    "Turns on or off all recording functionality. Will not reset anything from existing session, will just stop recording any new data. Default: true"
  ],
  [COMPONENT_NAME, "Core"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
  true, // default enabled
  true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
  {
    params ["_value"];
    if (!isServer) exitWith {};
    EFUNC(recorder,init);
  }, // function that will be executed once on mission start and every time the setting is changed.
  false // requires restart to apply
] call CBA_fnc_addSetting;
[
  QGVARMAIN(isDebug),
  "CHECKBOX", // setting type
  [
    "Debug Mode", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    "Enables increased logging of addon actions. Default: false"
  ],
  [COMPONENT_NAME, "Core"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
  false, // default enabled
  true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
  {}, // function that will be executed once on mission start and every time the setting is changed.
  false // requires restart to apply
] call CBA_fnc_addSetting;


ADDON = true;
