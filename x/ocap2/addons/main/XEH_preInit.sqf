#include "script_component.hpp"
#include "XEH_prep.sqf"


// This PreInit creates the settings on the server, only so that the global vars will be registered and synchronized with clients.

GVAR(allSettings) = [
  // Core
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
  ]
];



{
  _x call CBA_fnc_addSetting;
} forEach GVAR(allSettings);

ADDON = true;
