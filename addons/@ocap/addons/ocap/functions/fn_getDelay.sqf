/* ----------------------------------------------------------------------------
Script: ocap_fnc_exportData

Description:
	Determines the the appropriate interval at which to loop the <ocap_fnc_startCaptureLoop> function.

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

#include "script_macros.hpp"
private "_sleep";
isNil {
	_relativelyTime = time - ocap_startTime;
	_sleep = (ocap_captureFrameNo + 1) * ocap_frameCaptureDelay - _relativelyTime;
	if ((ocap_captureFrameNo % 10) isEqualTo 0) then {
		LOG(ARR4("DEBUG: Frame", ocap_captureFrameNo, "is created in ~", ocap_frameCaptureDelay - _sleep));
	};
	if (_sleep < 0) then {
		LOG(ARR3("ERROR: Frame delay is negative", ocap_captureFrameNo, _sleep));
		_sleep = 0;
	};
};
_sleep
