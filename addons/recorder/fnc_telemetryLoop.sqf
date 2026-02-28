#include "script_component.hpp"

/* ----------------------------------------------------------------------------
FILE: fnc_telemetryLoop.sqf

FUNCTION: OCAP_recorder_fnc_telemetryLoop

Description:
  Collects server telemetry data every 10 seconds and sends a single
  :TELEMETRY:FRAME: command to the extension. The extension handles routing
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
  if !(SHOULDSAVEEVENTS) exitWith {};
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
      private _localUnits = 0;
      private _localAlive = 0;
      private _remoteUnits = 0;
      private _remoteAlive = 0;
      {
        if (side _x isEqualTo _s) then {
          if (local _x) then {
            _localUnits = _localUnits + 1;
            if (alive _x) then { _localAlive = _localAlive + 1 };
          } else {
            _remoteUnits = _remoteUnits + 1;
            if (alive _x) then { _remoteAlive = _remoteAlive + 1 };
          };
        };
      } forEach _allUnits;

      private _localDead = 0;
      private _remoteDead = 0;
      {
        if (side _x isEqualTo _s) then {
          if (local _x) then {
            _localDead = _localDead + 1;
          } else {
            _remoteDead = _remoteDead + 1;
          };
        };
      } forEach _allDeadMen;

      private _localGroups = 0;
      private _remoteGroups = 0;
      {
        if (side _x isEqualTo _s) then {
          if (local _x) then {
            _localGroups = _localGroups + 1;
          } else {
            _remoteGroups = _remoteGroups + 1;
          };
        };
      } forEach _allGroups;

      private _localVeh = 0;
      private _remoteVeh = 0;
      private _localWH = 0;
      private _remoteWH = 0;
      {
        if (side _x isEqualTo _s) then {
          private _isWH = _x isKindOf "WeaponHolderSimulated";
          if (local _x) then {
            if (_isWH) then { _localWH = _localWH + 1 } else { _localVeh = _localVeh + 1 };
          } else {
            if (_isWH) then { _remoteWH = _remoteWH + 1 } else { _remoteVeh = _remoteVeh + 1 };
          };
        };
      } forEach _vehicles;

      _sideData pushBack [
        [_localUnits, _localAlive, _localDead, _localGroups, _localVeh, _localWH],
        [_remoteUnits, _remoteAlive, _remoteDead, _remoteGroups, _remoteVeh, _remoteWH]
      ];
    } forEach [east, west, independent, civilian];

    // [3] Global entity counts
    private _weaponholders = {_x isKindOf "WeaponHolderSimulated"} count _vehicles;
    private _playersAlive = {alive _x} count _allPlayers;
    private _globalCounts = [
      {alive _x} count _allUnits,
      count _allDeadMen,
      count _allGroups,
      count _vehicles - _weaponholders,
      _weaponholders,
      _playersAlive,
      count _allPlayers - _playersAlive,
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
    [":TELEMETRY:FRAME:", [
      GVAR(captureFrameNo),
      [diag_fps, diag_fpsmin],
      _sideData,
      _globalCounts,
      _scripts,
      _weather,
      _playerData
    ]] call EFUNC(extension,sendData);

    private _dur = round ((diag_tickTime - _start) * 1000);
    if (_dur < 10000) then {
      private _msg = format["Telemetry logged in %1ms", _dur];
      LOG(_msg);
    } else {
      private _msg = format["Telemetry took > 10s: %1ms", _dur];
      WARNING(_msg);
    };
  };
}, 10] call CBA_fnc_addPerFrameHandler;
