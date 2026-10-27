#include "script_component.hpp"

INFO("Module enabled. Starting up...");

// Initialize session
GVAR(sessionReady) = false;
GVAR(sessionPending) = false;


// The extension answers through callbacks: storage readiness builds the mission context, and
// :MISSION:OK: for the pending registration sets sessionReady, which lets the recorder send data.
addMissionEventHandler ["ExtensionCallback", {_this call FUNC(handleCallback)}];


INFO("Initializing extension...");
GVAR(initTimer) = diag_tickTime;
[":SYS:INIT:", []] call FUNC(sendData);
true
