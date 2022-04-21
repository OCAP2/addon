#include "script_component.hpp"

params ["_unit"];
_id = _unit getVariable QGVARMAIN(id);
if (isNil "_id") exitWith {};

_inVehicle = vehicle _unit != _unit;

// _viewDir = [0,0,0];
// if (!_inVehicle) then {
//   _viewDir = ([_unit] call CBA_fnc_modelHeadDir);// params ["_dir", "_yaw", "_pitch"];
// };

_data = [
  _id + 1,
  format ["Name=%1", [_unit] call FUNC(getName)],
  [_unit] call FUNC(formatPosLngLat),
  format ["Color=%1", [_unit] call FUNC(getColor)],
  format ["Health=%1", [0, 1 - (damage _vehicle)] select (alive _x)],
  format ["Visible=%1", [1, 0] select _inVehicle]
];

_extraData = [];
if (GVAR(captureFrameNo) % (5 / GVAR(frameCaptureDelay)) == 0) then {

    private _scores = [];
    if (isPlayer _unit && isMultiplayer) then {
      getPlayerScores _unit params ["_infantry", "_softVehicles", "_armour", "_air", "_deaths", "_total"];

      _scores = [
        format ["A3_ScoresInf=%1", _infantry],
        format ["A3_ScoresSoft=%1", _softVehicles],
        format ["A3_ScoresArmour=%1", _armour],
        format ["A3_ScoresAir=%1", _air],
        format ["A3_ScoresDeaths=%1", _deaths],
        format ["A3_ScoresTotal=%1", _total]
      ] joinString ",";
    };



  _extraData = [
    format ["CallSign=%1", [_unit] call FUNC(getName)],
    format ["Coalition=%1", [_unit] call FUNC(getCoalition)],

    // format ["PilotHeadPitch=%1", _viewDir#2],
    // format ["PilotHeadYaw=%1", _viewDir#1],
    format ["Group=%1", str group _unit],

    "Type=Ground+Light+Human+Infantry",
    format ["AI=%1", [1, 0] select (isPlayer _unit)],
    format ["A3_IsAI=%1", [1, 0] select (isPlayer _unit)],
    format ["A3_IsPlayer=%1", [0, 1] select (isPlayer _unit)],
    format ["A3_Behaviour=%1", behaviour _unit],
    format ["A3_UnitCombatMode=%1", unitCombatMode _unit],
    format ["A3_Skill=%1", skill _unit],
    format ["A3_IsCaptive=%1", [0, 1] select (captive _unit)],
    format ["A3_IsFleeing=%1", [0, 1] select (fleeing _unit)],
    format ["A3_LifeState=%1", lifeState _unit],
    format ["A3_IncapacitatedState=%1", ["", incapacitatedState _unit ] select (lifeState _unit == "INCAPACITATED")],
    format ["A3_IsBleeding=%1", [0, 1] select (isBleeding _unit)],
    format ["A3_IsBurning=%1", [0, 1] select (isBurning _unit)],
    format ["A3_Morale=%1", morale _unit],
    format ["A3_Stance=%1", stance _unit],
    format ["A3_IsReady=%1", [0, 1] select (unitReady _unit)],
    format ["A3_GroupFormation=%1", formation group _unit],
    format ["A3_NetId=%1", _unit call BIS_fnc_netId],
    ["", format ["A3_OwnerId=%1", owner _unit]] select isServer,
    // TODO - squadParams
    _scores
  ];
};

[(_data + _extraData) joinString ","] call FUNC(sendData);
