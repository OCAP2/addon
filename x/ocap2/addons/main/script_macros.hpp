// Header: script_macros.hpp
// Defines macros imported to other functions

#define PREFIX OCAP2

#ifdef COMPONENT_BEAUTIFIED
    #define COMPONENT_NAME QUOTE(PREFIX - COMPONENT_BEAUTIFIED)
#else
    #define COMPONENT_NAME QUOTE(PREFIX - COMPONENT)
#endif

// The current version of OCAP2.
#define VERSION 1.0
#define VERSION_STR 1.0.0
#define VERSION_AR 1,0,0
#define VERSION_REQUIRED 2.08

// define: LOG
// Used for logging messages via the extension.
#define OCAPEXTLOG(_args) [":LOG:", _args] call EFUNC(extension,sendData)

// #define DEBUG_MODE_NORMAL
#define DEBUG_MODE_FULL

// define: BOOL
// Forces a true/false return of input.
#define BOOL(_cond) ([0,1] select (_cond))

// define: ARR2
// Resolves to array, used for entry to <LOG> that requires array input.
#define ARR2(_arg1, _arg2) [_arg1, _arg2]
#define ARR3(_arg1, _arg2, _arg3) [_arg1, _arg2, _arg3]
#define ARR4(_arg1, _arg2, _arg3, _arg4) [_arg1, _arg2, _arg3, _arg4]
#define ARR5(_arg1, _arg2, _arg3, _arg4, _arg5) [_arg1, _arg2, _arg3, _arg4, _arg5]
#define ARR6(_arg1, _arg2, _arg3, _arg4, _arg5, _arg6) [_arg1, _arg2, _arg3, _arg4, _arg5, _arg6]




#include "\x\cba\addons\main\script_macros_common.hpp"
#include "\x\cba\addons\xeh\script_xeh.hpp"
