/*
  FILE: fnc_eh_disconnected.sqf

  FUNCTION: OCAP_recorder_fnc_eh_disconnected

  Description:

    This function uses the <OCAP_EH_HandleDisconnect> event handler to log "disconnected" events to the timeline. It will exclude any body left over from further recording.

  Parameters:
    See the wiki for details. <https://community.bistudio.com/wiki/Arma_3:_Mission_Event_Handlers#HandleDisconnect>

  Returns:
    False [Bool]

  Examples:
    > call FUNC(eh_disconnected);

  Public:
    No

  Author:
    IndigoFox
*/

#include "script_component.hpp"

params ["_unit", "_id", "_uid", "_name"];

["disconnected", _name, _uid] call FUNC(recordPlayerConnectionEvent);

if (_unit getVariable [QGVARMAIN(isInitialized), false]) then {
  [":SOLDIER:DELETE:", [
    _unit getVariable [QGVARMAIN(id), -1],
    GVAR(captureFrameNo)
  ]] call EFUNC(extension,sendData);
  _unit setVariable [QGVARMAIN(exclude), true];
  if (!isNil QGVAR(trackedUnits)) then {
    GVAR(trackedUnits) deleteAt (_unit getVariable [QGVARMAIN(id), -1]);
  };
};

// saveOnEmpty: if this was the last player, save immediately
if (
  EGVAR(settings,saveOnEmpty) &&
  !isNil QGVAR(startTime) &&
  {(call CBA_fnc_players) - [_unit] isEqualTo []} &&
  {(GVAR(frameCaptureDelay) * GVAR(captureFrameNo)) / 60 >= GVAR(minMissionTime)}
) then {
  GVAR(autoRestartAfterEmptyPending) = true;
  [nil, "Recording ended due to server being empty"] call FUNC(exportData);
};

false;
