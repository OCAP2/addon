#include "script_component.hpp"
#include "XEH_prep.sqf"

GVAR(allSettings) = [
  // Core
  [
    QGVARMAIN(tacviewEnabled),
    "CHECKBOX", // setting type
    [
      "Tacview Recording Enabled", // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
      "Adds Tacview ACMI as an output format. Will not work unless core OCAP2 is also enabled. Default: true"
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
