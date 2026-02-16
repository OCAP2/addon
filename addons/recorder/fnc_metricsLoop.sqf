#include "script_component.hpp"

/* ----------------------------------------------------------------------------
FILE: fnc_metricsLoop.sqf

FUNCTION: OCAP_recorder_fnc_metricsLoop

Description:
  Collects server telemetry data every 10 seconds and sends a single
  :TELEMETRY: command to the extension. The extension handles routing
  to mission recording (FPS) and InfluxDB (all metrics).

Parameters:
  None

Returns:
  None

Public:
  No

Author:
  OCAP Team
---------------------------------------------------------------------------- */

[{
  [] spawn {
    private _start = diag_tickTime;

    // Snapshot game state
    private _allUnits = allUnits;
    private _allDeadMen = allDeadMen;
    private _allGroups = allGroups;
    private _vehicles = vehicles;
    private _allPlayers = call BIS_fnc_listPlayers;

    // [2] Per-side entity counts: [east, west, independent, civilian]
    // Each side: [[serverLocal], [remote]]
    // Each locality: [units_total, units_alive, units_dead, groups, vehicles, weaponholders]
    private _sideData = [];
    {
      private _s = _x;
      private _sUnits = _allUnits select {side _x isEqualTo _s};
      private _sDead = _allDeadMen select {side _x isEqualTo _s};
      private _sGroups = _allGroups select {side _x isEqualTo _s};
      private _sVeh = _vehicles select {side _x isEqualTo _s};

      private _localUnits = _sUnits select {local _x};
      private _remoteUnits = _sUnits select {!local _x};
      private _localDead = _sDead select {local _x};
      private _remoteDead = _sDead select {!local _x};
      private _localGroups = _sGroups select {local _x};
      private _remoteGroups = _sGroups select {!local _x};
      private _localVeh = _sVeh select {local _x && !(_x isKindOf "WeaponHolderSimulated")};
      private _remoteVeh = _sVeh select {!local _x && !(_x isKindOf "WeaponHolderSimulated")};
      private _localWH = _sVeh select {local _x && _x isKindOf "WeaponHolderSimulated"};
      private _remoteWH = _sVeh select {!local _x && _x isKindOf "WeaponHolderSimulated"};

      _sideData pushBack [
        [count _localUnits, {alive _x} count _localUnits, count _localDead, count _localGroups, count _localVeh, count _localWH],
        [count _remoteUnits, {alive _x} count _remoteUnits, count _remoteDead, count _remoteGroups, count _remoteVeh, count _remoteWH]
      ];
    } forEach [east, west, independent, civilian];

    // [3] Global entity counts
    private _globalCounts = [
      {alive _x} count _allUnits,
      count _allDeadMen,
      count _allGroups,
      {!(_x isKindOf "WeaponHolderSimulated")} count _vehicles,
      {_x isKindOf "WeaponHolderSimulated"} count _vehicles,
      {alive _x} count _allPlayers,
      {!alive _x} count _allPlayers,
      count _allPlayers
    ];

    // [4] Running scripts
    private _scripts = diag_activeScripts + [
      if (isClass(configFile >> "CfgPatches" >> "cba_main")) then {
        count CBA_common_perFrameHandlerArray
      } else {0}
    ];

    // [5] Weather
    private _weather = [
      fog, overcast, rain, humidity, waves,
      windDir, windStr, gusts, lightnings,
      moonIntensity, moonPhase date, sunOrMoon
    ];

    // [6] Player network data
    private _playerData = [];
    {
      if (_x isEqualTo []) then {continue};
      _x params ["", "", "_uid", "_name", "", "", "", "_isHC", "", "_net", "_unit"];
      if (isNull _unit || _isHC) then {continue};
      _net params ["_ping", "_bw", "_desync"];
      _playerData pushBack [_uid, _name, _ping, _bw, _desync];
    } forEach (allUsers apply {getUserInfo _x});

    // Single telemetry call — extension handles routing and formatting
    [":TELEMETRY:", [
      GVAR(captureFrameNo),
      [diag_fps, diag_fpsmin],
      _sideData,
      _globalCounts,
      _scripts,
      _weather,
      _playerData
    ]] call EFUNC(extension,sendData);

    private _dur = diag_tickTime - _start;
    if (_dur < 10) then {
      private _msg = format["Telemetry logged in %1 ms", _dur];
      LOG(_msg);
    } else {
      private _msg = format["Telemetry took > 10s: %1 ms", _dur];
      WARNING(_msg);
    };
  };
}, 10] call CBA_fnc_addPerFrameHandler;
