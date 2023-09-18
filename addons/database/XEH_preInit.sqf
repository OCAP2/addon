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
      "Database Recording Enabled", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "Turns on or off most recording functionality. Will not reset anything from existing session, will just stop recording most new data. Note: For record/pause switching, use the CBA events! Default: true"
    ],
    [COMPONENT_NAME, "Core"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
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
