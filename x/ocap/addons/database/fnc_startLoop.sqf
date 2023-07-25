#include "script_component.hpp"

// PFHs to gather additional data

// server fps
[{
  [":FPS:", [
    EGVAR(recorder,captureFrameNo),
    diag_fps,
    diag_fpsmin
  ]] call FUNC(sendData);
}, 10] call CBA_fnc_addPerFrameHandler;
