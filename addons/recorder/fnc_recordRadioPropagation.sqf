/* ----------------------------------------------------------------------------
FILE: fnc_recordRadioPropagation.sqf

FUNCTION: OCAP_recorder_fnc_recordRadioPropagation

Description:
  Reads the TFAR and ACRE CBA settings that affect radio range on the server
  and writes them once as `tfarSettings` and `acreSettings` events. Playback
  uses those values for the approximate-range overlay; if a mod is not loaded
  on the server its baked defaults are stamped instead.

  The two mods do not share coefficients. TFAR uses
  `TFAR_terrain_interception_coefficient` (default 7) and
  `TFAR_globalRadioRangeCoef` (default 1). ACRE uses
  `acre_sys_core_terrainLoss` (0–1, default 1) plus
  `acre_sys_signal_signalModel` (default 2 = LOS Multipath). Approximate
  coverage for an ACRE radio must not inherit the TFAR values.

  Server-only. Radio sampling is client-local, but these CBA settings are
  registered with the server flag and live in missionNamespace when the
  server has the mod loaded.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(recordRadioPropagation);

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!isServer || {!SHOULDSAVEEVENTS} || {!EGVAR(extension,sessionReady)}) exitWith {};

private _tfarLoaded = isClass (configFile >> "CfgPatches" >> "tfar_core");
private _tfarSource = "default";

// TFAR writes the live copy to TF_terrain_interception_coefficient from the
// CBA setting TFAR_terrain_interception_coefficient (slider 0–20, default 7).
private _coef = missionNamespace getVariable "TFAR_terrain_interception_coefficient";
if (isNil "_coef") then {
  _coef = missionNamespace getVariable "TF_terrain_interception_coefficient";
};
if (isNil "_coef" || {!(_coef isEqualType 0)}) then {
  _coef = 7;
} else {
  _tfarSource = "cba";
};

private _rangeCoef = missionNamespace getVariable "TFAR_globalRadioRangeCoef";
if (isNil "_rangeCoef" || {!(_rangeCoef isEqualType 0)}) then {
  _rangeCoef = 1;
} else {
  _tfarSource = "cba";
};

[":EVENT:GENERAL:", [
  GVAR(captureFrameNo),
  "tfarSettings",
  [createHashMapFromArray [
    ["terrainInterceptionCoefficient", _coef],
    ["globalRadioRangeCoef", _rangeCoef],
    ["tfarLoaded", _tfarLoaded],
    ["source", _tfarSource]
  ]] call FUNC(encodeJSON)
]] call EFUNC(extension,sendData);

// ACRE's live `acre_sys_signal_terrainScaling` is written only on clients
// (`setLossModelScale` exits on dedicated). The CBA setting itself is global,
// so the dedicated server still has `acre_sys_core_terrainLoss` when ACRE is
// in the server mod list.
private _acreLoaded = isClass (configFile >> "CfgPatches" >> "acre_main");
private _acreSource = "default";

private _terrainLoss = missionNamespace getVariable "acre_sys_core_terrainLoss";
if (isNil "_terrainLoss" || {!(_terrainLoss isEqualType 0)}) then {
  _terrainLoss = 1;
} else {
  _acreSource = "cba";
};

private _signalModel = missionNamespace getVariable "acre_sys_signal_signalModel";
if (isNil "_signalModel" || {!(_signalModel isEqualType 0)}) then {
  _signalModel = 2; // SIGNAL_MODEL_LOS_MULTIPATH
} else {
  _acreSource = "cba";
  if (_signalModel < 0 || {_signalModel > 3}) then {
    _signalModel = 2;
  };
};

private _ignoreAntenna = missionNamespace getVariable "acre_sys_core_ignoreAntennaDirection";
if (isNil "_ignoreAntenna" || {!(_ignoreAntenna isEqualType true)}) then {
  _ignoreAntenna = false;
} else {
  _acreSource = "cba";
};

[":EVENT:GENERAL:", [
  GVAR(captureFrameNo),
  "acreSettings",
  [createHashMapFromArray [
    ["terrainLoss", _terrainLoss],
    ["signalModel", _signalModel],
    ["ignoreAntennaDirection", _ignoreAntenna],
    ["acreLoaded", _acreLoaded],
    ["source", _acreSource]
  ]] call FUNC(encodeJSON)
]] call EFUNC(extension,sendData);
