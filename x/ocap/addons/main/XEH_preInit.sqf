// FILE: CBA Settings

#include "script_component.hpp"
#include "XEH_prep.sqf"


// This PreInit creates the settings on the server, only so that the global vars will be registered and synchronized with clients.

GVAR(allSettings) = [
  // Section: Core

  /*
    CBA Setting: OCAP_enabled
    Description:
      Turns on or off most recording functionality. Will not reset anything from existing session, will just stop recording most new data. Note: For record/pause switching, use the CBA events! Default: true

    Setting Name:
      Recording Enabled

    Value Type:
      Boolean
  */
  [
    QGVARMAIN(enabled),
    "CHECKBOX", // setting type
    [
      "Recording Enabled", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "Turns on or off most recording functionality. Will not reset anything from existing session, will just stop recording most new data. Note: For record/pause switching, use the CBA events! Default: true"
    ],
    [COMPONENT_NAME, "Core"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    true, // default enabled
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    false // requires restart to apply
  ],

  /*
    CBA Setting: OCAP_isDebug
    Description:
      Enables increased logging of addon actions. Default: false

    Setting Name:
      Debug Mode

    Value Type:
      Boolean
  */
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
  ],

  /*
    CBA Setting: OCAP_enabledAdministratorUI
    Description:
      Turns on or off the Administrator UI in the briefing diary. Default: true

    Setting Name:
      Administrator UI Enabled

    Value Type:
      Boolean
  */
  [
    QGVARMAIN(enabledAdministratorUI),
    "CHECKBOX", // setting type
    [
      "Administrator UI Enabled", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "Turns on or off the Administrator UI in the briefing diary. Default: true"
    ],
    [COMPONENT_NAME, "Core"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    true, // default enabled
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    false // requires restart to apply
  ],

  /*
    CBA Setting: OCAP_administratorList
    Description:
      An array or server-visible variable referencing one that is a list of playerUIDs. Additional briefing diary or UI elements may be available for more accessible control over OCAP's features. Takes effect on player server connection. Format: [] OR myAdminPUIDs | Default: []

    Setting Name:
      Administrators

    Value Type:
      Stringified Array

    Example:
      > "['76561198000000000', '76561198000000001']"
  */
  [
    QGVARMAIN(administratorList),
    "EDITBOX", // setting type
    [
      "Administrators", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "An array or server-visible variable referencing one that is a list of playerUIDs. Additional briefing diary or UI elements may be available for more accessible control over OCAP's features. Takes effect on player server connection. Format: [] OR myAdminPUIDs | Default: []"
    ],
    [COMPONENT_NAME, "Core"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    "[]", // default enabled
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    false // requires restart to apply
  ]
];

{
  _x call CBA_fnc_addSetting;
} forEach GVAR(allSettings);

ADDON = true;
