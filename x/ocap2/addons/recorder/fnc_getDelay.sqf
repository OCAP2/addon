/* ----------------------------------------------------------------------------
Script: FUNC(exportData)

Description:
  Determines the the appropriate interval at which to loop the <FUNC(captureLoop)> function.

  Устанавливает точную задержку между кадрами

Parameters:
  None

Returns:
  Sleep duration [Number]

Examples:
  --- Code
  call ocap_fnc_getDelay;
  ---

Public:
  No

Author:
  Dell
---------------------------------------------------------------------------- */
#include "script_component.hpp"

private "_sleep";
isNil {
  _elapsedTime = time - GVAR(startTime);
  _sleep = (GVAR(captureFrameNo) + 1) * EGVAR(settings,frameCaptureDelay) - _elapsedTime;

  if ((GVAR(captureFrameNo) % 10) isEqualTo 0) then {
    LOG(ARR4("DEBUG: Frame", GVAR(captureFrameNo), "is created in ~", EGVAR(settings,frameCaptureDelay) - _sleep));
  };
  if (_sleep < 0) then {
    LOG(ARR3("ERROR: Frame delay is negative", GVAR(captureFrameNo), _sleep));
    _sleep = 0.4;
  };
};
_sleep
