// Header: script_macros.hpp
// Defines macros imported to other functions

#include "\userconfig\ocap\config.hpp"

// define: REQUIRED_VERSION
// The version of Arma required to run this mod correctly.
#define REQUIRED_VERSION 2.04
// define: OCAP_ADDON_VERSION
// The current version of OCAP2.
#define OCAP_ADDON_VERSION "1.2.0-alpha"
// define: LOG
// Used for logging messages via the extension.
#define LOG(_args) [":LOG:", _args] call ocap_fnc_extension

// define: DEBUG
// Conditional, used for logging debug messages when <ocap_isDebug> is true.
#if ocap_isDebug
	#define DEBUG(_args) [":LOG:", _args] call ocap_fnc_extension
#else
	#define DEBUG(_args) /* disabled */
#endif

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
