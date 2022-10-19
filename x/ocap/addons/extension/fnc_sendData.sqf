/* ----------------------------------------------------------------------------
FILE: fnc_sendData.sqf

FUNCTION: OCAP_extension_fnc_sendData

Description:
	Manages raw extension calls and returns values / logs errors where relevant.

Parameters:
	_command - The extension command to call [String]
	_args - The arguments to send [Array]

Returns:
	Depends

Examples:
	> [":VERSION", []] call EFUNC(extension,sendData);

Public:
	No

Author:
	Dell, Zealot
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_command","_args"];

private _dllName = "OcapReplaySaver2";

private _res = _dllName callExtension [_command, _args];

_res params ["_result","_returnCode","_errorCode"];

if (_errorCode != 0 || _returnCode != 0) then {
  textLogFormat ["Error when calling extension: %1", [_result, _returnCode, _errorCode, _command, _args]];
};

if (
	_command isEqualTo ":VERSION:" &&
	_result isEqualType ""
) then {parseSimpleArray _result};
