// HEADER: script_macros.hpp
// Defines macros imported to other functions

// DEFINE: PREFIX
#define PREFIX OCAP

#ifdef COMPONENT_BEAUTIFIED
  // DEFINE: COMPONENT_NAME
  #define COMPONENT_NAME QUOTE(PREFIX - COMPONENT_BEAUTIFIED)
#else
  #define COMPONENT_NAME QUOTE(PREFIX - COMPONENT)
#endif

// DEFINE: ADDON
// <PREFIX>_<COMPONENT>

// The current version of OCAP.

// DEFINE: VERSION
#define VERSION 2.0

// DEFINE: VERSION_STR
#define VERSION_STR 2.0.0

// DEFINE: VERSION_AR
#define VERSION_AR 2,0,0

// DEFINE: VERSION_REQUIRED
#define VERSION_REQUIRED 2.10

// MACRO: LOG
// Used for logging messages to the extension (ocap-ext log file).
#define OCAPEXTLOG(_args) [":LOG:", _args] call EFUNC(extension,sendData)

// MACRO: SYSCHAT
// Used for debug purposes to send a string to all clients with interfaces.
#define SYSCHAT remoteExec ["systemChat", [0, -2] select isDedicated]

// MACRO: SHOULDSAVEEVENTS
// Used to determine if events should currently be saved based on <OCAP_recorder_recording> and <OCAP_recorder_startTime>.
#define SHOULDSAVEEVENTS ((missionNamespace getVariable [QGVAR(recording), false]) && missionNamespace getVariable [QGVAR(startTime), -1] > -1)

#define DEBUG_MODE_NORMAL
// #define DEBUG_MODE_FULL

// DEFINE: BOOL
// Forces a true/false return of input.
#define BOOL(_cond) ([0,1] select (_cond))

// DEFINE: ARR2
// Resolves arguments to array, used for entries to <LOG> that requires array input.
#define ARR2(_arg1, _arg2) [_arg1, _arg2]
#define ARR3(_arg1, _arg2, _arg3) [_arg1, _arg2, _arg3]
#define ARR4(_arg1, _arg2, _arg3, _arg4) [_arg1, _arg2, _arg3, _arg4]
#define ARR5(_arg1, _arg2, _arg3, _arg4, _arg5) [_arg1, _arg2, _arg3, _arg4, _arg5]
#define ARR6(_arg1, _arg2, _arg3, _arg4, _arg5, _arg6) [_arg1, _arg2, _arg3, _arg4, _arg5, _arg6]


#include "\x\cba\addons\main\script_macros_common.hpp"
#include "\x\cba\addons\xeh\script_xeh.hpp"


