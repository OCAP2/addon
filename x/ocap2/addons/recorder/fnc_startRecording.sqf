/*
  Start Recording

  This is the initial recording start function. If it hasn't been called from anywhere already, it'll get everything in order to initiate a session for this mission.
*/
#include "script_component.hpp"

// disregard recording attempts while OCAP is disabled.
if (!GVARMAIN(enabled)) exitWith {};

// if recording started earlier and startTime has been noted, only restart the capture loop with any updated settings.
if (!isNil QGVAR(startTime) && GVAR(recording)) exitWith {
  OCAPEXTLOG(["OCAP2 was asked to record and is already recording!"]);
};
if (!isNil QGVAR(startTime) && !GVAR(recording)) exitWith {
  call FUNC(captureLoop);
};

// Notify the extension
[":START:", [worldName, GVAR(missionName), getMissionConfigValue ["author", ""], GVAR(frameCaptureDelay)]] call EFUNC(extension,sendData);
[":SET:VERSION:", [GVARMAIN(version)]] call EFUNC(extension,sendData);

// Add mission event handlers
call FUNC(addEventMission);
// Track initial times
[] call FUNC(updateTime);

GVAR(nextId) = 0;
call FUNC(captureLoop);
