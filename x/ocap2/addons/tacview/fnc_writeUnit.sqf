#include "script_component.hpp"

params ["_unit"];
_id = _unit getVariable QGVARMAIN(id);
if (isNil "_id") exitWith {};

_inVehicle = vehicle _unit != _unit;

private _scores = _unit getVariable [QGVAR(scores), ""];
if (GVAR(captureFrameNo) % (10 / GVAR(frameCaptureDelay)) == 0) then {
  if !(isPlayer _unit && isMultiplayer) exitWith {};

  getPlayerScores _unit params ["_infantry", "_softVehicles", "_armour", "_air", "_deaths", "_total"];
  _scores = [
		format ["A3_ScoresInf=%1", _infantry],
		format ["A3_ScoresSoft=%1", _softVehicles],
		format ["A3_ScoresArmour=%1", _armour],
		format ["A3_ScoresAir=%1", _air],
		format ["A3_ScoresDeaths=%1", _deaths],
		format ["A3_ScoresTotal=%1", _total]
	] joinString ",";
  _unit setVariable [QGVAR(scores), _scores];
};

[
  format ["A3_ScoresInf=%1", _infantry],
  format ["A3_ScoresSoft=%1", _softVehicles],
  format ["A3_ScoresArmour=%1", _armour],
  format ["A3_ScoresAir=%1", _air],
  format ["A3_ScoresDeaths=%1", _deaths],
  format ["A3_ScoresTotal=%1", _total]
] joinString ",";

[[
  _id + 1,
  format ["Name=%1", _x getVariable QGVARMAIN(displayName)],
  "Type=Ground+Light+Human+Infantry",
  [_unit] call FUNC(formatPosLngLat),
  format ["CallSign=%1", [_unit] call FUNC(getName)],
  format ["Coalition=%1", [_unit] call FUNC(getCoalition)],
  format ["Color=%1", [
      "",
      [_unit] call FUNC(getColor),
      "Orange"
    ] select (_unit getVariable [QGVARMAIN(lifestate), 1])
  ],
  format ["Group=%1", str group _unit],
  format ["Health=%1", 1 - (damage _unit)],
  format ["Visible=%1", [1, 0] select _inVehicle],
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
] joinString ","] call FUNC(sendData);
