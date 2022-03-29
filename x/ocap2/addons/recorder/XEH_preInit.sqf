#include "script_component.hpp"
#include "XEH_prep.sqf"

GVAR(allSettings) = [
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
  ],

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
    false // requires restart to apply
  ],


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
    true // requires restart to apply
  ],

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
  ],

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
  ],

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
  ],

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
  ],

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
  ],

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
  ],



  // SAVING SETTINGS
  [
    QEGVAR(settings,saveTag),
    "EDITBOX", // setting type
    [
      "Mission Type Tag", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "If not overriden by the exportData CBA event or if a mission is auto-saved, this will be used to categorize and filter the recording in the database and web list of missions."
    ],
    [COMPONENT_NAME, "Save/Export Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    "TvT", // default string value
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    false // requires restart to apply
  ],

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
    false // requires restart to apply
  ],

  [
    QEGVAR(settings,saveOnEmpty),
    "CHECKBOX", // setting type
    [
      "Auto-Save When No Players", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "Will automatically save recording when there are 0 players on the server and existing data accounts for more time than the minimum save duration setting. Default: true"
    ],
    [COMPONENT_NAME, "Recording Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    true, // default enabled
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    false // requires restart to apply
  ],

  [
    QEGVAR(settings,minMissionTime),
    "SLIDER", // setting type
    [
      "Required Duration to Save", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "A recording must be at least this long (in minutes) to auto-save. Calling an 'ocap_exportData' CBA server event will override this restriction. Default: 20"
    ],
    [COMPONENT_NAME, "Save/Export Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    [
        1, // min
        120, // max
        20, // default
        0, // trailing decimals
        false // percentage
    ], // data for this setting: [min, max, default, number of shown trailing decimals]
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    true // requires restart to apply
  ]
];

{
  _x call CBA_fnc_addSetting;
} forEach GVAR(allSettings);

if (!is3DEN) then {
  call FUNC(init);
};

ADDON = true;
