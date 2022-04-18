#include "script_component.hpp"

params ["_vehicle"];
_id = _vehicle getVariable QGVARMAIN(id);
if (isNil "_id") exitWith {};

_basicAttributes = [
  _id + 1,
  format ["Name=%1", _vehicle getVariable [QGVARMAIN(displayName), ""]],
  format ["Type=%1", [_vehicle] call FUNC(getClass)],
  [_vehicle] call FUNC(formatPosLngLat),
  format ["Pilot=%1", if (!isNull currentPilot _vehicle) then { [currentPilot _vehicle] call FUNC(getName) } else { "" }],
  format ["Coalition=%1", [_vehicle] call FUNC(getCoalition)],
  format ["Color=%1", [_vehicle] call FUNC(getColor)],
  format ["Group=%1", [group _vehicle, ""] select (isNull (group _vehicle))],
  format ["Health=%1", 1 - (damage _vehicle)],
  format ["A3_Fuel=%1", fuel _vehicle],
  format ["A3_IsEngineOn=%1", [0, 1] select (isEngineOn _vehicle)],
  format ["A3_NetId=%1", _vehicle call BIS_fnc_netId],
  if (isServer) then { format ["A3_OwnerId=%1", owner _vehicle] } else { "" }
];

_planeAttributes = if ((_vehicle call BIS_fnc_objectType) select 1 == "Plane") then {
  ([currentPilot _vehicle] call CBA_fnc_modelHeadDir) params ["_dir", "_yaw", "_pitch"];
  [
    format ["Throttle=%1", airplaneThrottle _vehicle],
    format ["PilotHeadPitch=%1", _pitch],
    format ["PilotHeadYaw=%1", _yaw]
  ];
} else {[]};

_helicopterAttributes = if ((_vehicle call BIS_fnc_objectType) select 1 == "Helicopter") then {
  ([currentPilot _vehicle] call CBA_fnc_modelHeadDir) params ["_dir", "_yaw", "_pitch"];
  _basics = [
    format ["A3_IsAutoHoverOn=%1", [0, 1] select (isAutoHoverOn _vehicle)],
    format ["A3_IsAFM=%1", [0, 1] select (difficultyEnabledRTD && (isObjectRTD _vehicle))],
    format ["PilotHeadPitch=%1", _pitch],
    format ["PilotHeadYaw=%1", _yaw]
  ];

  _afm = if (difficultyEnabledRTD && (isObjectRTD _vehicle)) then {
    weightRTD _vehicle params ["_weightFuselage", "_weightCrew", "_weightFuel", "_weightCustom", "_weightWeapons"];
    [
      format ["Throttle=%1", collectiveRTD _vehicle],
      format ["FuelWeight=%1", _weightFuel],
      format ["A3_AFM_Collective=%1", collectiveRTD _vehicle],
      format ["A3_AFM_RotorBrake=%1", getRotorBrakeRTD _vehicle],
      format ["A3_AFM_NumberEngines=%1", numberOfEnginesRTD _vehicle],
      format ["A3_AFM_Weight=%1", _weightFuselage + _weightCrew + _weightFuel + _weightCustom + _weightWeapons]
    ] +
    (["A3_AFM_IsEngineOn", enginesIsOnRTD _vehicle, { if (_this) then { "1" } else { "0" } }] call _formatArrayAttributes) +
    (["A3_AFM_EnginePower", enginesPowerRTD _vehicle] call _formatArrayAttributes) +
    (["A3_AFM_EngineTorque", enginesTorqueRTD _vehicle] call _formatArrayAttributes) +
    (["A3_AFM_EngineRPM", enginesRpmRTD _vehicle] call _formatArrayAttributes) +
    (["A3_AFM_EngineTargetRPM", getEngineTargetRPMRTD _vehicle] call _formatArrayAttributes) +
    (["A3_AFM_RotorRPM", rotorsRpmRTD _vehicle] call _formatArrayAttributes);
  } else {[]};

  _basics + _afm;
} else {[]};

((_basicAttributes + _planeAttributes + _helicopterAttributes) joinString ",") call FUNC(sendData);
