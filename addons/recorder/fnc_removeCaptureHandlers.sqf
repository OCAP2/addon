/* ----------------------------------------------------------------------------
FILE: fnc_removeCaptureHandlers.sqf

FUNCTION: OCAP_recorder_fnc_removeCaptureHandlers

Description:
  Removes the per-frame handlers of the capture loop, the server FPS sampler
  and the weather sampler, when a recording ends.

Parameters:
  None

Returns:
  Nothing

Public:
  No

Author:
  Dell, Zealot, IndigoFox, TyroneMF (moved from OCAP_recorder_fnc_exportData)
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!isNil QGVAR(PFHObject)) then {
  [GVAR(PFHObject)] call CBA_fnc_deletePerFrameHandlerObject;
  GVAR(PFHObject) = nil;
};
if (!isNil QGVAR(serverFpsPFH)) then {
  [GVAR(serverFpsPFH)] call CBA_fnc_removePerFrameHandler;
  GVAR(serverFpsPFH) = nil;
};
if (!isNil QGVAR(weatherPFH)) then {
  [GVAR(weatherPFH)] call CBA_fnc_removePerFrameHandler;
  GVAR(weatherPFH) = nil;
};
