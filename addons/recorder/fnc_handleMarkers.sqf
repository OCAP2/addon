/* ----------------------------------------------------------------------------
FILE: fnc_handleMarkers.sqf

FUNCTION: OCAP_recorder_fnc_handleMarkers

Description:
  Used for tracking all markers in the vanilla Arma 3 system.

  This function creates a server-side CBA listener as well as local Event Handlers on the server and all clients. It facilitates marker creation, modification, and deletion that occurs across any machine or on the server.

  Delays are integrated into the system to allow for multi-line scripted marker creations during a mission to reflect correctly in the created marker during playback. These delays are accounted for so that playback reflects the true creation time.

  Due to the nature of locality and single-view playback, markers of the same name which exist in different states on different clients may display odd behavior during playback.

  Marker exclusions as configured in <OCAP_settings_excludeMarkerFromRecord> are handled client-side to avoid unnecessary network traffic.

  This will also wait until the mission proceeds past the briefing screen, then gather all existing markers and send them to the server for entry onto the Editor/Briefing Markers layer during playback.

  Applied during mission event handler application in <OCAP_recorder_fnc_addEventMission>.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(handleMarkers);

Public:
  No

Author:
  IndigoFox, Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

// VARIABLE: OCAP_recorder_trackedMarkers
// Persistent global variable on server that defines unique marker names currently being tracked.
// Entries are added at marker create events and removed at marker delete events to avoid duplicate processing.
GVAR(trackedMarkers) = []; // Markers which we save into replay

// VARIABLE: OCAP_listener_markers
// Contains handle for <OCAP_handleMarker> CBA event handler.

// CBA Event: OCAP_handleMarker
// Handles marker creation, modification, and deletion events.
EGVAR(listener,markers) = [QGVARMAIN(handleMarker), {

  if (!SHOULDSAVEEVENTS) exitWith {};

  params["_eventType", "_mrk_name", "_mrk_owner", "_pos", "_type", "_shape", "_size", "_dir", "_brush", "_color", "_alpha", "_text", ["_forceGlobal", false], ["_creationTime", 0]];

  switch (_eventType) do {

    case "CREATED":{

      if (GVARMAIN(isDebug)) then {
        OCAPEXTLOG(ARR2("MARKER:CREATE: Processing marker data -- ", _mrk_name));
      };

      if (_mrk_name in GVAR(trackedMarkers)) exitWith {
        if (GVARMAIN(isDebug)) then {
          OCAPEXTLOG(ARR3("MARKER:CREATE: Marker", _mrk_name, "already tracked, exiting"));
        };
      };

      if (GVARMAIN(isDebug)) then {
        format["CREATE:MARKER: Valid CREATED process of %1, sending to extension", _mrk_name] SYSCHAT;
        OCAPEXTLOG(ARR3("CREATE:MARKER: Valid CREATED process of", _mrk_name, ", sending to extension"));
      };

      if (_type isEqualTo "") then {_type = "mil_dot"};
      GVAR(trackedMarkers) pushBackUnique _mrk_name;

      private _mrk_color = "";
      if (_color == "Default") then {
        _mrk_color = (configfile >> "CfgMarkers" >> _type >> "color") call BIS_fnc_colorConfigToRGBA call bis_fnc_colorRGBtoHTML;
      } else {
        _mrk_color = (configfile >> "CfgMarkerColors" >> _color >> "color") call BIS_fnc_colorConfigToRGBA call bis_fnc_colorRGBtoHTML;
      };

      private ["_sideOfMarker"];
      if (_mrk_owner isEqualTo objNull) then {
        _forceGlobal = true;
        _mrk_owner = -1;
        _sideOfMarker = -1;
      } else {
        _sideOfMarker = (side _mrk_owner) call BIS_fnc_sideID;
        _mrk_owner = _mrk_owner getVariable[QGVARMAIN(id), 0];
      };

      if (_sideOfMarker isEqualTo 4 ||
      (["Projectile#", _mrk_name] call BIS_fnc_inString) ||
      (["Detonation#", _mrk_name] call BIS_fnc_inString) ||
      (["Mine#", _mrk_name] call BIS_fnc_inString) ||
      (["ObjectMarker", _mrk_name] call BIS_fnc_inString) ||
      (["moduleCoverMap", _mrk_name] call BIS_fnc_inString) ||
      _forceGlobal) then {_sideOfMarker = -1};

      private ["_polylinePos"];
      if (count _pos > 3) then {
        _polylinePos = [];
        for [{_i = 0}, {_i < ((count _pos) - 1)}, {_i = _i + 1}] do {
          _polylinePos pushBack [_pos # (_i), _pos # (_i + 1)];
          _i = _i + 1;
        };
        _pos = _polylinePos;
      };

      if (isNil "_dir") then {
        _dir = 0;
      } else {if (_dir isEqualTo "") then {_dir = 0}};

      private _captureFrameNo = GVAR(captureFrameNo);
      if (_creationTime > 0) then {
        private _delta = time - _creationTime;
        private _lastFrameTime = (GVAR(captureFrameNo) * GVAR(frameCaptureDelay)) + GVAR(startTime);
        if (_delta > (time - _lastFrameTime)) then { // marker was initially created in some frame(s) before
          _captureFrameNo = ceil _lastFrameTime - (_delta / GVAR(frameCaptureDelay));
          private _logParams = (str [GVAR(captureFrameNo), time, _creationTime, _delta, _lastFrameTime, _captureFrameNo]);

          if (GVARMAIN(isDebug)) then {
            OCAPEXTLOG(ARR2("CREATE:MARKER: adjust frame ", _logParams));
          };
        };
      };

      private _logParams = (str [_mrk_name, _dir, _type, _text, _captureFrameNo, -1, _mrk_owner, _mrk_color, _size, _sideOfMarker, _pos, _shape, _alpha, _brush]);

      [":MARKER:CREATE:", [_mrk_name, _dir, _type, _text, _captureFrameNo, -1, _mrk_owner, _mrk_color, _size, _sideOfMarker, _pos, _shape, _alpha, _brush]] call EFUNC(extension,sendData);
    };

    case "UPDATED":{

      if (_mrk_name in GVAR(trackedMarkers)) then {
        if (isNil "_dir") then {_dir = 0};
        [":MARKER:MOVE:", [_mrk_name, GVAR(captureFrameNo), _pos, _dir, _alpha]] call EFUNC(extension,sendData);
      };
    };

    case "DELETED":{

      if (_mrk_name in GVAR(trackedMarkers)) then {

        if (GVARMAIN(isDebug)) then {
          format["MARKER:DELETE: Marker %1", _mrk_name] SYSCHAT;
          OCAPEXTLOG(ARR3("MARKER:DELETE: Marker", _mrk_name, "deleted"));
        };

        [":MARKER:DELETE:", [_mrk_name, GVAR(captureFrameNo)]] call EFUNC(extension,sendData);
        GVAR(trackedMarkers) = GVAR(trackedMarkers) - [_mrk_name];
      };
    };
  };
}] call CBA_fnc_addEventHandler;





// handle created markers
{
  /*
    Event Handler: MarkerCreated
    Description:
      Tracks marker creations. Present on server and all clients. Ignores remotely-owned markers.

      References <OCAP_settings_excludeMarkerFromRecord> on each local machine to determine if a marker should be recorded.

      If so, sends marker data to <OCAP_handleMarker> on the server for processing.
 */
  addMissionEventHandler["MarkerCreated", {
    params["_marker", "_channelNumber", "_owner", "_local"];

    if (!_local) exitWith {};

    // check for excluded values in marker name. if name contains at least one value, skip sending traffic to server
    // if value is undefined, then skip
    private _isExcluded = false;
    if (!isNil QEGVAR(settings,excludeMarkerFromRecord)) then {
      {
        if ((str _marker) find _x >= 0) exitWith {
          _isExcluded = true;
        };
      } forEach (parseSimpleArray EGVAR(settings,excludeMarkerFromRecord));
    };
    if (_isExcluded) exitWith {};

    private _event = _this;
    _event pushBack time;

    [{
      params["_marker", "_channelNumber", "_owner", "_local", "_creationTime"];
      _pos = ATLToASL (markerPos [_marker, true]);
      _type = markerType _marker;
      _shape = markerShape _marker;
      _size = markerSize _marker;
      _dir = markerDir _marker;
      _brush = markerBrush _marker;
      _color = markerColor _marker;
      _text = markerText _marker;
      _alpha = markerAlpha _marker;
      _polyline = markerPolyline _marker;
      if (count _polyline != 0) then {
        _pos = _polyline;
      };

      [QGVARMAIN(handleMarker), ["CREATED", _marker, _owner, _pos, _type, _shape, _size, _dir, _brush, _color, _alpha, _text, false, _creationTime]] call CBA_fnc_serverEvent;
    }, _event, 2] call CBA_fnc_waitAndExecute;
  }];

  // handle marker moves/updates
  /*
    Event Handler: MarkerUpdated
    Description:
      Tracks marker updates (moves). Present on server and all clients. Ignores remotely-owned markers.

      References <OCAP_settings_excludeMarkerFromRecord> on each local machine to determine if a marker should be recorded.

      If so, sends marker data to <OCAP_handleMarker> on the server for processing.
  */
  addMissionEventHandler["MarkerUpdated", {
    params["_marker", "_local"];

    if (!_local) exitWith {};

    // check for excluded values in marker name. if name contains at least one value, skip sending traffic to server
    // if value is undefined, then skip
    private _isExcluded = false;
    if (!isNil QEGVAR(settings,excludeMarkerFromRecord)) then {
      {
        if ((str _marker) find _x >= -1) exitWith {
          _isExcluded = true;
        };
      } forEach (parseSimpleArray EGVAR(settings,excludeMarkerFromRecord));
    };
    if (_isExcluded) exitWith {};

    private _pos = ATLToASL (markerPos [_marker, true]);

    [QGVARMAIN(handleMarker), ["UPDATED", _marker, player, _pos, "", "", "", markerDir _marker, "", "", markerAlpha _marker]] call CBA_fnc_serverEvent;
  }];

  // handle marker deletions
  /*
    Event Handler: MarkerDeleted
    Description:
      Tracks marker deletions. Present on server and all clients. Ignores remotely-owned markers.

      References <OCAP_settings_excludeMarkerFromRecord> on each local machine to determine if a marker should be recorded.

      If so, sends marker data to <OCAP_handleMarker> on the server for processing.
  */
  addMissionEventHandler["MarkerDeleted", {
    params["_marker", "_local"];

    if (!_local) exitWith {};

    // check for excluded values in marker name. if name contains at least one value, skip sending traffic to server
    // if value is undefined, then skip
    private _isExcluded = false;
    if (!isNil QEGVAR(settings,excludeMarkerFromRecord)) then {
      {
        if ((str _marker) find _x > -1) exitWith {
          _isExcluded = true;
        };
      } forEach (parseSimpleArray EGVAR(settings,excludeMarkerFromRecord));
    };
    if (_isExcluded) exitWith {};

    [QGVARMAIN(handleMarker), ["DELETED", _marker, player]] call CBA_fnc_serverEvent;
  }];
} remoteExec["call", 0, true];



// collect all initial markers & add event handlers to clients
[
  {getClientStateNumber > 8 && !isNil QGVAR(startTime)},
  {
    {
      private _marker = _x;

      // check for excluded values in marker name. if name contains at least one value, skip sending traffic to server
      // if value is undefined, then skip
      private _isExcluded = false;
      if (!isNil QEGVAR(settings,excludeMarkerFromRecord)) then {
        {
          if ((_marker) find _x >= 0) exitWith {
            _isExcluded = true;
          };
        } forEach (parseSimpleArray EGVAR(settings,excludeMarkerFromRecord));
      };
      if (_isExcluded) then {continue};


      // "Started polling starting markers" remoteExec ["hint", 0];
      // get intro object markers
      _pos = ATLToASL (markerPos [_marker, true]);
      _type = markerType _marker;
      _shape = markerShape _marker;
      _size = markerSize _marker;
      _dir = markerDir _marker;
      _brush = markerBrush _marker;
      _color = markerColor _marker;
      _text = markerText _marker;
      _alpha = markerAlpha _marker;
      _polyline = markerPolyline _marker;
      if (count _polyline != 0) then {
        _pos = _polyline;
      };



      if (isNil "_dir") then {
        _dir = 0;
      } else {if (_dir isEqualTo "") then {_dir = 0}};

      _forceGlobal = true;

      // "_eventType", "_mrk_name", "_mrk_owner","_pos", "_type", "_shape", "_size", "_dir", "_brush", "_color", "_alpha", "_text", "_forceGlobal"
      [QGVARMAIN(handleMarker), ["CREATED", _marker, objNull, _pos, _type, _shape, _size, _dir, _brush, _color, _alpha, _text, _forceGlobal]] call CBA_fnc_localEvent;

    } forEach (allMapMarkers select {_x find "_USER_DEFINED" == -1});

    LOG("GETINITIALMARKERS: Successfully parsed init-scripted and editor-placed markers");
    if (GVARMAIN(isDebug)) then {
      "GETINITIALMARKERS: Successfully parsed init-scripted and editor-placed markers" SYSCHAT;
      OCAPEXTLOG(["GETINITIALMARKERS: Successfully parsed init-scripted and editor-placed markers"]);
    };
  }
] call CBA_fnc_waitUntilAndExecute;
