#include "script_component.hpp"

[":EVENT:",
  [GVAR(captureFrameNo), "connected", _this select 2]
] call EFUNC(extension,sendData);
