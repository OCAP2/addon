// Client-side CBA settings registration with raw stringtable keys.
// On the server these settings are already registered by main/recorder/database,
// so CBA_fnc_addSetting skips them. On the client (where the server addons aren't
// loaded) this registers the settings so they appear in CBA addon options.
//
// Display names and tooltips are stored as raw stringtable keys (e.g. "STR_...").
// CBA's settings UI calls isLocalized/localize at render time, so each client
// sees its own language — provided the stringtable is available (i.e. this
// translations addon is installed).

{
  _x call CBA_fnc_addSetting;
} forEach [
  ["OCAP_enabled",                          "CHECKBOX", ["STR_OCAP_main_RecordingEnabled",               "STR_OCAP_main_RecordingEnabled_Tooltip"],               ["OCAP - Main",     "STR_OCAP_main_SettingsCore"],              true,                          true, {}, false],
  ["OCAP_isDebug",                          "CHECKBOX", ["STR_OCAP_main_DebugMode",                      "STR_OCAP_main_DebugMode_Tooltip"],                      ["OCAP - Main",     "STR_OCAP_main_SettingsCore"],              false,                         true, {}, false],
  ["OCAP_administratorList",                "EDITBOX",  ["STR_OCAP_main_Administrators",                 "STR_OCAP_main_Administrators_Tooltip"],                 ["OCAP - Main",     "STR_OCAP_main_SettingsCore"],              "[]",                          true, {}, false],
  ["OCAP_database_enabled",                 "CHECKBOX", ["STR_OCAP_database_DatabaseRecordingEnabled",    "STR_OCAP_database_DatabaseRecordingEnabled_Tooltip"],    ["OCAP - Database", "STR_OCAP_database_SettingsCore"],           true,                          true, {}, true],
  ["OCAP_settings_autoStart",               "CHECKBOX", ["STR_OCAP_recorder_AutoStartRecording",         "STR_OCAP_recorder_AutoStartRecording_Tooltip"],         ["OCAP - Recorder", "STR_OCAP_recorder_SettingsAutoStart"],     true,                          true, {}, true],
  ["OCAP_settings_minPlayerCount",          "SLIDER",   ["STR_OCAP_recorder_MinimumPlayerCount",         "STR_OCAP_recorder_MinimumPlayerCount_Tooltip"],         ["OCAP - Recorder", "STR_OCAP_recorder_SettingsAutoStart"],     [1, 150, 15, 0, false],        true, {}, false],
  ["OCAP_settings_frameCaptureDelay",       "SLIDER",   ["STR_OCAP_recorder_FrameCaptureDelay",          "STR_OCAP_recorder_FrameCaptureDelay_Tooltip"],          ["OCAP - Recorder", "STR_OCAP_recorder_SettingsCore"],          [0.30, 10, 1, 2, false],       true, {}, true],
  ["OCAP_settings_preferACEUnconscious",    "CHECKBOX", ["STR_OCAP_recorder_UseACE3Medical",             "STR_OCAP_recorder_UseACE3Medical_Tooltip"],             ["OCAP - Recorder", "STR_OCAP_recorder_SettingsCore"],          true,                          true, {}, false],
  ["OCAP_settings_excludeClassFromRecord",  "EDITBOX",  ["STR_OCAP_recorder_ClassnamesToExclude",        "STR_OCAP_recorder_ClassnamesToExclude_Tooltip"],        ["OCAP - Recorder", "STR_OCAP_recorder_SettingsExclusions"],    "['ACE_friesAnchorBar']",      true, {}, false],
  ["OCAP_settings_excludeKindFromRecord",   "EDITBOX",  ["STR_OCAP_recorder_KindOfToExclude",            "STR_OCAP_recorder_KindOfToExclude_Tooltip"],            ["OCAP - Recorder", "STR_OCAP_recorder_SettingsExclusions"],    "['WeaponHolder']",            true, {}, false],
  ["OCAP_settings_excludeMarkerFromRecord", "EDITBOX",  ["STR_OCAP_recorder_MarkerPrefixesExclude",      "STR_OCAP_recorder_MarkerPrefixesExclude_Tooltip"],      ["OCAP - Recorder", "STR_OCAP_recorder_SettingsExclusions"],    "['SystemMarker_','ACE_BFT_']",true, {}, false],
  ["OCAP_settings_trackTickets",            "CHECKBOX", ["STR_OCAP_recorder_TicketTracking",             "STR_OCAP_recorder_TicketTracking_Tooltip"],             ["OCAP - Recorder", "STR_OCAP_recorder_SettingsExtraTracking"], true,                          true, {}, false],
  ["OCAP_settings_trackTimes",              "CHECKBOX", ["STR_OCAP_recorder_MissionTimeTracking",        "STR_OCAP_recorder_MissionTimeTracking_Tooltip"],        ["OCAP - Recorder", "STR_OCAP_recorder_SettingsExtraTracking"], false,                         true, {}, false],
  ["OCAP_settings_trackTimeInterval",       "SLIDER",   ["STR_OCAP_recorder_MissionTimeTrackingInterval","STR_OCAP_recorder_MissionTimeTrackingInterval_Tooltip"],["OCAP - Recorder", "STR_OCAP_recorder_SettingsExtraTracking"], [5, 25, 10, 0, false],         true, {}, false],
  ["OCAP_settings_saveTag",                 "EDITBOX",  ["STR_OCAP_recorder_MissionTag",                 "STR_OCAP_recorder_MissionTag_Tooltip"],                 ["OCAP - Recorder", "STR_OCAP_recorder_SettingsSaveExport"],    "TvT",                         true, {}, false],
  ["OCAP_settings_saveMissionEnded",        "CHECKBOX", ["STR_OCAP_recorder_SaveOnEnd",                  "STR_OCAP_recorder_SaveOnEnd_Tooltip"],                  ["OCAP - Recorder", "STR_OCAP_recorder_SettingsSaveExport"],    true,                          true, {}, false],
  ["OCAP_settings_saveOnEmpty",             "CHECKBOX", ["STR_OCAP_recorder_SaveOnEmpty",                "STR_OCAP_recorder_SaveOnEmpty_Tooltip"],                ["OCAP - Recorder", "STR_OCAP_recorder_SettingsSaveExport"],    true,                          true, {}, false],
  ["OCAP_settings_minMissionTime",          "SLIDER",   ["STR_OCAP_recorder_MinimumSaveDuration",        "STR_OCAP_recorder_MinimumSaveDuration_Tooltip"],        ["OCAP - Recorder", "STR_OCAP_recorder_SettingsSaveExport"],    [1, 120, 20, 0, false],        true, {}, true]
];
