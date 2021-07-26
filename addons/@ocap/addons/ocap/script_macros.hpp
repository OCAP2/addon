#include "\userconfig\ocap\config.hpp"
#define REQUIRED_VERSION 2.04
#define OCAP_ADDON_VERSION "1.1.0"
#define LOG(_args) [":LOG:", _args] call ocap_fnc_extension
#if ocap_isDebug
	#define DEBUG(_args) [":LOG:", _args] call ocap_fnc_extension
#else
	#define DEBUG(_args) /* disabled */
#endif
#define BOOL(_cond) ([0,1] select (_cond))

#define ARR2(_arg1, _arg2) [_arg1, _arg2]
#define ARR3(_arg1, _arg2, _arg3) [_arg1, _arg2, _arg3]
#define ARR4(_arg1, _arg2, _arg3, _arg4) [_arg1, _arg2, _arg3, _arg4]
#define ARR5(_arg1, _arg2, _arg3, _arg4, _arg5) [_arg1, _arg2, _arg3, _arg4, _arg5]
#define ARR6(_arg1, _arg2, _arg3, _arg4, _arg5, _arg6) [_arg1, _arg2, _arg3, _arg4, _arg5, _arg6]
