#include "script_component.hpp"

// PFHs to gather additional data

// server fps to DB
[{
  [":FPS:", [
    EGVAR(recorder,captureFrameNo),
    diag_fps,
    diag_fpsmin
  ]] call FUNC(sendData);
}, 10] call CBA_fnc_addPerFrameHandler;


[{ // entity counts to InfluxDB
  [] spawn {
    private _start = diag_tickTime;
    private _allUnits = allUnits;
    private _allDeadMen = allDeadMen;
    private _allGroups = allGroups;
    private _vehicles = vehicles;
    private _allPlayers = call BIS_fnc_listPlayers;

    {
      private _thisSide = _x;
      private _thisSideStr = _thisSide call BIS_fnc_sideNameUnlocalized;

      // Number of server (local) owned units
      [":METRIC:", [
        "server_performance",
        format["entity_count_server_%2", _thisSideStr],
        ["tag", "side", _thisSideStr] joinString "::",
        ["field", "int", "units_total", {
            side _x isEqualTo _thisSide &&
            local _x
          } count _allUnits] joinString "::",
        ["field", "int", "units_alive", {
            side _x isEqualTo _thisSide &&
            local _x
          } count _allUnits] joinString "::",
        ["field", "int", "units_dead", {
            side _x isEqualTo _thisSide &&
            local _x
          } count _allDeadMen] joinString "::",
        ["field", "int", "groups_total", {
            side _x isEqualTo _thisSide &&
            local _x
          } count _allGroups] joinString "::",
        ["field", "int", "vehicles_total", {
            side _x isEqualTo _thisSide &&
            local _x &&
            !(_x isKindOf "WeaponHolderSimulated")
          } count _vehicles] joinString "::",
        ["field", "int", "vehicles_weaponholder", {
            side _x isEqualTo _thisSide &&
            local _x &&
            (_x isKindOf "WeaponHolderSimulated")
          } count _vehicles] joinString "::"
      ]] call FUNC(sendData);


      // Number of remote, non-local units
      [":METRIC:", [
        "server_performance",
        format["entity_count_remote_%2", _thisSideStr],
        ["field", "int", "units_total", {
            side _x isEqualTo _thisSide &&
            not (local _x)
          } count _allUnits] joinString "::",
        ["field", "int", "units_alive", {
            side _x isEqualTo _thisSide &&
            not (local _x)
          } count _allUnits] joinString "::",
        ["field", "int", "units_dead", {
            side _x isEqualTo _thisSide &&
            not (local _x)
          } count _allDeadMen] joinString "::",
        ["field", "int", "groups_total", {
            side _x isEqualTo _thisSide &&
            not (local _x)
          } count _allGroups] joinString "::",
        ["field", "int", "vehicles_total", {
            side _x isEqualTo _thisSide &&
            not (local _x) &&
            !(_x isKindOf "WeaponHolderSimulated")
          } count _vehicles] joinString "::",
        ["field", "int", "vehicles_weaponholder", {
            side _x isEqualTo _thisSide &&
            not (local _x) &&
            (_x isKindOf "WeaponHolderSimulated")
          } count _vehicles] joinString "::"
      ]] call FUNC(sendData);
    } forEach [east, west, independent, civilian];

    // Number of all units (global)
    [":METRIC:", [
      "server_performance",
      "entity_count_global_all",
      ["field", "int", "units_alive",
        count _allUnits] joinString "::",
      ["field", "int", "units_dead",
        count _allDeadMen] joinString "::",
      ["field", "int", "groups_total",
        count _allGroups] joinString "::",
      ["field", "int", "vehicles_total", {
        !(_x isKindOf "WeaponHolderSimulated")
        } count _vehicles] joinString "::",
      ["field", "int", "vehicles_weaponholder", {
        (_x isKindOf "WeaponHolderSimulated")
        } count _vehicles] joinString "::",
      ["field", "int", "players_alive", {
        alive _x
        } count _allPlayers] joinString "::",
      ["field", "int", "players_dead", {
        !alive _x
        } count _allPlayers] joinString "::"
    ]] call FUNC(sendData);

    [":METRIC:", [
      "server_performance",
      "player_count",
      ["field", "int", "players_connected",
        count _allPlayers] joinString "::"
    ]] call FUNC(sendData);


    {
      if (_x isEqualTo []) exitWith {nil};
      _x params ["_playerID", "_ownerId", "_playerUID", "_profileName", "_displayName", "_steamName", "_clientState", "_isHC", "_adminState", "_networkInfo", "_unit"];
      _networkInfo params ["_avgPing", "_avgBandwidth", "_desync"];


      if (_unit == objNull || _isHC) exitWith {false};

      [":METRIC:", [
        "player_performance",
        "network",
        ["tag", "playerUID", _playerUID] joinString "::",
        ["tag", "playerName", _profileName] joinString "::",
        ["field", "float", "avgPing",
          _avgPing] joinString "::",
        ["field", "float", "avgBandwidth",
          _avgBandwidth] joinString "::",
        ["field", "float", "desync",
          _desync] joinString "::"
      ]] call FUNC(sendData);

      true;
    } count (allUsers apply {getUserInfo _x});

    [":METRIC:", [
      "server_performance",
      "running_scripts",
      ["field", "int", "spawn",
        diag_activeScripts select 0] joinString "::",
      ["field", "int", "execVM",
        diag_activeScripts select 1] joinString "::",
      ["field", "int", "exec",
        diag_activeScripts select 2] joinString "::",
      ["field", "int", "execFSM",
        diag_activeScripts select 3] joinString "::",
      ["field", "int", "pfh",
          if (isClass(configFile >> "CfgPatches" >> "cba_main")) then {
            count CBA_common_perFrameHandlerArray
          } else {0}
        ] joinString "::"
    ]] call FUNC(sendData);

    [":METRIC:", [
      "server_performance",
      "fps",
      ["field", "float", "fps_avg",
        diag_fps toFixed 2] joinString "::",
      ["field", "float", "fps_min",
        diag_fpsMin toFixed 2] joinString "::"
    ]] call FUNC(sendData);

    [":METRIC:", [
      "mission_data",
      "time",
      ["field", "float", "diag_tickTime",
        diag_tickTime toFixed 2] joinString "::",
      ["field", "float", "serverTime",
        time toFixed 2] joinString "::",
      ["field", "float", "timeMultiplier",
        timeMultiplier toFixed 2] joinString "::",
      ["field", "float", "accTime",
        accTime toFixed 2] joinString "::"
    ]] call FUNC(sendData);

    [":METRIC:", [
      "mission_data",
      "weather",
      ["field", "float", "fog",
        fog] joinString "::",
      ["field", "float", "overcast",
        overcast] joinString "::",
      ["field", "float", "rain",
        rain] joinString "::",
      ["field", "float", "humidity",
        humidity] joinString "::",
      ["field", "float", "waves",
        waves] joinString "::",
      ["field", "float", "windDir",
        windDir] joinString "::",
      ["field", "float", "windStr",
        windStr] joinString "::",
      ["field", "float", "gusts",
        gusts] joinString "::",
      ["field", "float", "lightnings",
        lightnings] joinString "::",
      ["field", "float", "moonIntensity",
        moonIntensity] joinString "::",
      ["field", "float", "moonPhase",
        moonPhase date] joinString "::",
      ["field", "float", "sunOrMoon",
        sunOrMoon] joinString "::"
    ]] call FUNC(sendData);

    private _dur = diag_tickTime - _start;
    if (_dur < 10) then {
      private _msg = format["Metrics logged in %1 ms", _dur];
      LOG(_msg);
    } else {
      private _msg = format["Metrics took > 10s: logged in %1 ms", _dur];
      WARNING(_msg);
    };
  };
}, 10] call CBA_fnc_addPerFrameHandler;
