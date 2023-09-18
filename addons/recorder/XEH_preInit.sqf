// FILE: CBA Settings

#include "script_component.hpp"
#include "XEH_prep.sqf"

GVAR(allSettings) = [
  // Section: Auto-Start Settings

  /*
    CBA Setting: OCAP_settings_autoStart
    Description:
      Automatically start OCAP recordings at session start. Default: true

    Setting Name:
      Auto Start Recording

    Value Type:
      Boolean
  */
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

  /*
    CBA Setting: OCAP_settings_minPlayerCount
    Description:
      Auto-start will begin once this player count is reached. Default: 15

    Setting Name:
      Minimum Player Count

    Value Type:
      Number
  */
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


  // Section: Core

  /*
    CBA Setting: OCAP_settings_frameCaptureDelay
    Description:
      Positioning, medical status, and crew states of units and vehicles will be captured every X amount of seconds. Default: 1

    Setting Name:
      Frame Capture Delay

    Value Type:
      Number
  */
  [
    QEGVAR(settings,frameCaptureDelay),
    "SLIDER", // setting type
    [
      "Frame Capture Delay", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "Positioning, medical status, and crew states of units and vehicles will be captured every X amount of seconds. Default: 1"
    ],
    [COMPONENT_NAME, "Core"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    [
        0.30, // min
        10, // max
        1, // default
        2, // trailing decimals
        false // percentage
    ], // data for this setting: [min, max, default, number of shown trailing decimals]
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    true // requires restart to apply
  ],

  /*
    CBA Setting: OCAP_settings_preferACEUnconscious
    Description:
      If true, will check ACE3 medical status on units. If false, or ACE3 isn't loaded, fall back to vanilla. Default: true

    Setting Name:
      Use ACE3 Medical

    Value Type:
      Boolean
  */
  [
    QEGVAR(settings,preferACEUnconscious),
    "CHECKBOX", // setting type
    [
      "Use ACE3 Medical", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "If true, will check ACE3 medical status on units. If false, or ACE3 isn't loaded, fall back to vanilla. Default: true"
    ],
    [COMPONENT_NAME, "Core"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    true, // default enabled
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    false // requires restart to apply
  ],





  // Section: Exclusions

  /*
    CBA Setting: OCAP_settings_excludeClassFromRecord
    Description:
      Array of object classnames that should be excluded from recording. Use single quotes! Default: ['ACE_friesAnchorBar', 'WeaponHolderSimulated']

    Setting Name:
      Classnames to Exclude

    Value Type:
      Stringified Array

    Example:
      > "['ACE_friesAnchorBar']"
  */
  [
    QEGVAR(settings,excludeClassFromRecord),
    "EDITBOX", // setting type
    [
      "Classnames to Exclude", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "Array of object classnames that should be excluded from recording. Use single quotes! Default: ['ACE_friesAnchorBar', 'WeaponHolderSimulated']"
    ],
    [COMPONENT_NAME, "Exclusions"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    "['ACE_friesAnchorBar']", // default string value
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    false // requires restart to apply
  ],

  /*
    CBA Setting: OCAP_settings_excludeKindFromRecord
    Description:
      Array of classnames which, along with all child classes, should be excluded from recording. Use single quotes! Default: []

    Setting Name:
      Object KindOfs to Exclude

    Value Type:
      Stringified Array

    Example:
      > "['WeaponHolder']"
  */
  [
    QEGVAR(settings,excludeKindFromRecord),
    "EDITBOX", // setting type
    [
      "Object KindOfs to Exclude", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "Array of classnames which, along with all child classes, should be excluded from recording. Use single quotes! Default: []"
    ],
    [COMPONENT_NAME, "Exclusions"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    "['WeaponHolder']", // default string value
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    false // requires restart to apply
  ],

  /*
    CBA Setting: OCAP_settings_excludeMarkerFromRecord
    Description:
      Array of prefixes. Any markers matching these prefixes will be excluded from recording. Use single quotes! Default: ['SystemMarker_','ACE_BFT_']

    Setting Name:
      Marker Prefixes To Exclude

    Value Type:
      Stringified Array

    Example:
      > "['SystemMarker_','ACE_BFT_']"
  */
  [
    QEGVAR(settings,excludeMarkerFromRecord),
    "EDITBOX", // setting type
    [
      "Marker Prefixes to Exclude", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "Array of prefixes. Any markers matching these prefixes will be excluded from recording. Use single quotes! Default: ['SystemMarker_','ACE_BFT_']"
    ],
    [COMPONENT_NAME, "Exclusions"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    "['SystemMarker_','ACE_BFT_']", // default string value
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    false // requires restart to apply
  ],




  // Section: Extra Tracking

  /*
    CBA Setting: OCAP_settings_trackTickets
    Description:
      Will track respawn ticket counts for missionNamespace and each playable faction every 30th frame. Default: true

    Setting Name:
      Enable Ticket Tracking

    Value Type:
      Boolean
  */
  [
    QEGVAR(settings,trackTickets),
    "CHECKBOX", // setting type
    [
      "Enable Ticket Tracking", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "Will track respawn ticket counts for missionNamespace and each playable faction every 30th frame. Default: true"
    ],
    [COMPONENT_NAME, "Extra Tracking"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    true, // default enabled
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    false // requires restart to apply
  ],

  /*
    CBA Setting: OCAP_settings_trackTimes
    Description:
      Will continuously track in-game world time during a mission. Useful for accelerated/skipped time scenarios. Default: false

    Setting Name:
      Enable Mission Time Tracking

    Value Type:
      Boolean
  */
  [
    QEGVAR(settings,trackTimes),
    "CHECKBOX", // setting type
    [
      "Enable Mission Time Tracking", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "Will continuously track in-game world time during a mission. Useful for accelerated/skipped time scenarios. Default: false"
    ],
    [COMPONENT_NAME, "Extra Tracking"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    false, // default enabled
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    false // requires restart to apply
  ],

  /*
    CBA Setting: OCAP_settings_trackTimeInterval
    Description:
      If <OCAP_settings_trackTimes> is enabled, it will be checked every X capture frames. Default: 10

    Setting Name:
      Mission Time Tracking Interval

    Value Type:
      Number
  */
  [
    QEGVAR(settings,trackTimeInterval),
    "SLIDER", // setting type
    [
      "Mission Time Tracking Interval", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "If time tracking is enabled, it will be checked every X capture frames. Default: 10"
    ],
    [COMPONENT_NAME, "Extra Tracking"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
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



  // Section: Save/Export Settings

  /*
    CBA Setting: OCAP_settings_saveTag
    Description:
      If not overriden by the <OCAP_exportData> CBA event or if a mission is auto-saved, this will be used to categorize and filter the recording in the database and web list of missions.

    Setting Name:
      Mission Type Tag

    Value Type:
      String
  */
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

  /*
    CBA Setting: OCAP_settings_saveMissionEnded
    Description:
      If true, automatically save and export the mission when the MPEnded event fires. Default: true

    Setting Name:
      Auto-save on MPEnded Event

    Value Type:
      Boolean
  */
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

  /*
    CBA Setting: OCAP_settings_saveOnEmpty
    Description:
      Will automatically save recording when there are 0 players on the server and existing data accounts for more time than the minimum save duration setting. Default: true

    Setting Name:
      Auto-Save When No Players

    Value Type:
      Boolean
  */
  [
    QEGVAR(settings,saveOnEmpty),
    "CHECKBOX", // setting type
    [
      "Auto-Save When No Players", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "Will automatically save recording when there are 0 players on the server and existing data accounts for more time than the minimum save duration setting. Default: true"
    ],
    [COMPONENT_NAME, "Save/Export Settings"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    true, // default enabled
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    false // requires restart to apply
  ],

  /*
    CBA Setting: OCAP_settings_minMissionTime
    Description:
      A recording must be at least this long (in minutes) to auto-save. Calling an <OCAP_exportData> CBA server event will override this restriction. Default: 20

    Setting Name:
      Required Duration to Sav

    Value Type:
      Boolean
  */
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

ADDON = true;
