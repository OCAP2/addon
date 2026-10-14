/* ----------------------------------------------------------------------------
FILE: fnc_recordWeather.sqf

FUNCTION: OCAP_recorder_fnc_recordWeather

Description:
  Samples the recording server's current weather and writes an additive
  `weather` event. Vanilla environment commands cover overcast, rain, fog,
  wind, gusts, lightnings, humidity, waves and moon phase. When ACE Weather
  is loaded and its CBA `ace_weather_enabled` setting is on, ACE humidity
  and air temperature replace the vanilla readings; ACE wind simulation
  already writes through `setWind`, so `wind` / `windDir` are the live values
  either way.

  Server-only. Weather is global, not client-local.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(recordWeather);

Public:
  No

Author:
  IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!isServer || {!SHOULDSAVEEVENTS} || {!EGVAR(extension,sessionReady)}) exitWith {};
if !(EGVAR(settings,trackWeather)) exitWith {};

private _round3 = {
  round (_this * 1000) / 1000
};

private _aceWeather = isClass (configFile >> "CfgPatches" >> "ace_weather")
  && {missionNamespace getVariable ["ace_weather_enabled", false]};

private _humidity = humidity;
if (_aceWeather) then {
  private _aceHumidity = missionNamespace getVariable "ace_weather_currentHumidity";
  if (!isNil "_aceHumidity" && {_aceHumidity isEqualType 0}) then {
    _humidity = _aceHumidity;
  };
};

private _pairs = [
  ["overcast", overcast call _round3],
  ["rain", rain call _round3],
  ["fog", fog call _round3],
  ["windSpeed", round ((vectorMagnitude wind) * 10) / 10],
  ["windDir", round windDir],
  ["gusts", gusts call _round3],
  ["lightnings", lightnings call _round3],
  ["humidity", _humidity call _round3],
  ["waves", waves call _round3],
  ["moonPhase", (moonPhase date) call _round3],
  ["ace", _aceWeather]
];

if (_aceWeather) then {
  private _temperature = missionNamespace getVariable "ace_weather_currentTemperature";
  if (!isNil "_temperature" && {_temperature isEqualType 0}) then {
    _pairs pushBack ["temperature", round (_temperature * 10) / 10];
  };
};

[":EVENT:GENERAL:", [
  // The PFH can fire before the capture loop has produced a frame. A sample
  // stamped -1 wraps past the end of the recording and never shows in Stats.
  GVAR(captureFrameNo) max 0,
  "weather",
  [createHashMapFromArray _pairs] call FUNC(encodeJSON)
]] call EFUNC(extension,sendData);
