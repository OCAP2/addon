#include "\userconfig\ocap\config.hpp"
#include "script_macros.hpp"

ocap_markers_tracked = []; // Markers which we saves into replay

// On the dedicated server, the color of the markers is blue
{
	_x params ["_name", "_color"];
	profilenamespace setVariable [_name, _color];
} forEach [
	["map_blufor_r", 0],
	["map_blufor_g", 0.3],
	["map_blufor_b", 0.6],
	["map_independent_r", 0],
	["map_independent_g", 0.5],
	["map_independent_b", 0],
	["map_civilian_r", 0.4],
	["map_civilian_g", 0],
	["map_civilian_b", 0.5],
	["map_unknown_r", 0.1],
	["map_unknown_g", 0.6],
	["map_unknown_b", 0],
	["map_opfor_r", 0.5],
	["map_opfor_g", 0],
	["map_opfor_b", 0]
];

// create CBA event handler to be called on server
ocap_markers_handle = ["ocap_handleMarker", {
	params["_eventType", "_mrk_name", "_mrk_owner", "_pos", "_type", "_shape", "_size", "_dir", "_brush", "_color", "_alpha", "_text", "_forceGlobal"];

	switch (_eventType) do {

		case "CREATED":{
			if (ocap_isDebug) then {LOG(ARR2("MARKER:CREATE: Processing marker data -- ", _this))};

			if (_mrk_name in ocap_markers_tracked) exitWith {
				if (ocap_isDebug) then {LOG(ARR3("MARKER:CREATE: Marker", _mrk_name, "already tracked, exiting"))};
			};

			if (ocap_isDebug) then {LOG(ARR4("MARKER:CREATE: Valid CREATED process of marker from", _mrk_owner, "for", _mrk_name))};

			if (_type isEqualTo "") then {_type = "mil_dot"};
			ocap_markers_tracked pushBackUnique _mrk_name;

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
				_mrk_owner = _mrk_owner getVariable["ocap_id", 0];
			};

			if (_sideOfMarker isEqualTo 4 ||
			(["Projectile#", _mrk_name] call BIS_fnc_inString) ||
			(["Detonation#", _mrk_name] call BIS_fnc_inString) ||
			(["Mine#", _mrk_name] call BIS_fnc_inString) ||
			(["ObjectMarker", _mrk_name] call BIS_fnc_inString) ||
			(["moduleCoverMap", _mrk_name] call BIS_fnc_inString) ||
			(!isNil "_forceGlobal")) then {_sideOfMarker = -1};

			private ["_polylinePos"];
			if (count _pos > 2) then {
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

			private _logParams = (str [_mrk_name, _dir, _type, _text, ocap_captureFrameNo, -1, _mrk_owner, _mrk_color, _size, _sideOfMarker, _pos, _shape, _alpha, _brush]);
			if (ocap_isDebug) then {LOG(ARR4("CREATE:MARKER: Valid CREATED process of", _mrk_name, ", sending to extension -- ", _logParams))};

			[":MARKER:CREATE:", [_mrk_name, _dir, _type, _text, ocap_captureFrameNo, -1, _mrk_owner, _mrk_color, _size, _sideOfMarker, _pos, _shape, _alpha, _brush]] call ocap_fnc_extension;

		};

		case "UPDATED":{

			if (_mrk_name in ocap_markers_tracked) then {
				if (isNil "_dir") then {_dir = 0};

				if (ocap_isDebug) then {
					private _logParams = str [_mrk_name, ocap_captureFrameNo, _pos, _dir, _alpha];
					LOG(ARR4("MARKER:MOVE: Valid UPDATED process of", _mrk_name, ", sending to extension -- ", _logParams));
				};

				[":MARKER:MOVE:", [_mrk_name, ocap_captureFrameNo, _pos, _dir, _alpha]] call ocap_fnc_extension;
			};
		};

		case "DELETED":{

			if (_mrk_name in ocap_markers_tracked) then {
				if (ocap_isDebug) then {LOG(ARR3("MARKER:DELETE: Marker", _mrk_name, "deleted"))};
				[":MARKER:DELETE:", [_mrk_name, ocap_captureFrameNo]] call ocap_fnc_extension;
				ocap_markers_tracked = ocap_markers_tracked - [_mrk_name];
			};
		};
	};
}] call CBA_fnc_addEventHandler;





// handle created markers
{
	addMissionEventHandler["MarkerCreated", {
		params["_marker", "_channelNumber", "_owner", "_local"];

		if (!_local) exitWith {};

		// check for excluded values in marker name. if name contains at least one value, skip sending traffic to server
		// if value is undefined, then skip
		private _isExcluded = false;
		if (!isNil "ocap_excludeMarkerFromRecord") then {
			{
				if ([_x, _marker] call BIS_fnc_inString) exitWith {
					_isExcluded = true;
				};
			} forEach ocap_excludeMarkerFromRecord;
		};
		if (_isExcluded) exitWith {};

		// wait two seconds in case marker is skipped
		[{
			params["_marker", "_channelNumber", "_owner", "_local"];
			_pos = markerPos _marker;
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
			} else {
				_pos resize 2;
			};

			["ocap_handleMarker", ["CREATED", _marker, _owner, _pos, _type, _shape, _size, _dir, _brush, _color, _alpha, _text]] call CBA_fnc_serverEvent;
		}, _this, 2] call CBA_fnc_waitAndExecute;
	}];

	// handle marker moves/updates
	addMissionEventHandler["MarkerUpdated", {
		params["_marker", "_local"];

		if (!_local) exitWith {};

		// check for excluded values in marker name. if name contains at least one value, skip sending traffic to server
		// if value is undefined, then skip
		private _isExcluded = false;
		if (!isNil "ocap_excludeMarkerFromRecord") then {
			{
				if ([_x, _marker] call BIS_fnc_inString) exitWith {
					_isExcluded = true;
				};
			} forEach ocap_excludeMarkerFromRecord;
		};
		if (_isExcluded) exitWith {};

		["ocap_handleMarker", ["UPDATED", _marker, player, markerPos _marker, "", "", "", markerDir _marker, "", "", markerAlpha _marker]] call CBA_fnc_serverEvent;
	}];

	// handle marker deletions
	addMissionEventHandler["MarkerDeleted", {
		params["_marker", "_local"];

		if (!_local) exitWith {};

		// check for excluded values in marker name. if name contains at least one value, skip sending traffic to server
		// if value is undefined, then skip
		private _isExcluded = false;
		if (!isNil "ocap_excludeMarkerFromRecord") then {
			{
				if ([_x, _marker] call BIS_fnc_inString) exitWith {
					_isExcluded = true;
				};
			} forEach ocap_excludeMarkerFromRecord;
		};
		if (_isExcluded) exitWith {};

		["ocap_handleMarker", ["DELETED", _marker, player]] call CBA_fnc_serverEvent;
	}];
} remoteExec["call", 0, true];



// collect all initial markers & add event handlers to clients
[
	{count allPlayers > 0},
	{
		private _exclude = [
			"bis_fnc_moduleCoverMap_0",
			"bis_fnc_moduleCoverMap_90",
			"bis_fnc_moduleCoverMap_180",
			"bis_fnc_moduleCoverMap_270",
			"bis_fnc_moduleCoverMap_border",
			"respawn",
			"respawn_west",
			"respawn_east",
			"respawn_guerrila",
			"respawn_civilian"
		];

		{
			private _marker = _x;
			// "Started polling starting markers" remoteExec ["hint", 0];
			// get intro object markers
			_pos = markerPos _marker;
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
			} else {
				_pos resize 2;
			};

			if (isNil "_dir") then {
				_dir = 0;
			} else {if (_dir isEqualTo "") then {_dir = 0}};

			if (["ObjectMarker", _marker] call BIS_fnc_inString) then {
				_type = "ObjectMarker";
				_colour = "ColorBlack";
			};
			if (["moduleCoverMap_dot", _marker] call BIS_fnc_inString) then {
				_type = "moduleCoverMap";
				_colour = "ColorBlack";
			};

			_forceGlobal = true;

			// "_eventType", "_mrk_name", "_mrk_owner","_pos", "_type", "_shape", "_size", "_dir", "_brush", "_color", "_alpha", "_text", "_forceGlobal"
			["ocap_handleMarker", ["CREATED", _marker, objNull, _pos, _type, _shape, _size, _dir, _brush, _color, _alpha, _text, _forceGlobal]] call CBA_fnc_localEvent;

		} forEach (allMapMarkers);

		LOG(["GETINITIALMARKERS: Successfully parsed init-scripted and editor-placed markers"]);
	}
] call CBA_fnc_waitUntilAndExecute;
