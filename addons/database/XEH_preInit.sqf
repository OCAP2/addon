#include "script_component.hpp"
#include "XEH_prep.sqf"

GVAR(allSettings) = [
  // Section: Core

  /*
    CBA Setting: OCAP_database_enabled
    Description:
      Turns on or off database recording functionality. Default: true

    Setting Name:
      Recording Enabled

    Value Type:
      Boolean
  */
  [
    QGVAR(enabled),
    "CHECKBOX", // setting type
    [
      LSTRING(DatabaseRecordingEnabled), // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      LSTRING(DatabaseRecordingEnabled_Tooltip)
    ],
    [COMPONENT_NAME, LSTRING(SettingsCore)], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    true, // default enabled
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {}, // function that will be executed once on mission start and every time the setting is changed.
    true // requires restart to apply
  ]
];

{
  _x call CBA_fnc_addSetting;
} forEach GVAR(allSettings);

ADDON = true;
