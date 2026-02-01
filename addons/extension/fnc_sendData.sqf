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

params ["_command","_args", ["_dllName", "ocap_recorder"]];

diag_log text format ["[OCAP] [EXT] >> Calling extension '%1' with command='%2', args=%3", _dllName, _command, _args];

private _res = _dllName callExtension [_command, _args];

_res params ["_result","_returnCode","_errorCode"];

diag_log text format ["[OCAP] [EXT] << Response: result='%1', returnCode=%2, errorCode=%3", _result, _returnCode, _errorCode];

if (_errorCode != 0 || _returnCode != 0) then {
  diag_log text format ["[OCAP] [EXT] ERROR when calling extension: %1", [_result, _returnCode, _errorCode, _command, _args]];
};

if (_command isEqualTo ":VERSION:" && _result isEqualType "") then {
  private _parsed = parseSimpleArray _result;
  diag_log text format ["[OCAP] [EXT] :VERSION: parsed result=%1, type=%2", _parsed, typeName _parsed];
  _parsed
};
