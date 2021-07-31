/* ----------------------------------------------------------------------------
Script: ocap_fnc_extension

Description:
	Manages raw extension calls and returns values / logs errors where relevant.

Parameters:
	_command - The extension command to call [String]
	_args - The arguments to send [Array]

Returns:
	Depends

Examples:
	--- Code
	[":VERSION", []] call ocap_fnc_extension;
	---

Public:
	No

Author:
	Dell, Zealot
---------------------------------------------------------------------------- */

params ["_command","_args"];

private _dllName = "OcapReplaySaver2";

private _res = _dllName callExtension [_command, _args];

_res params ["_result","_returnCode","_errorCode"];

if (_errorCode != 0 || _returnCode != 0) then {
	diag_log ["fnc_callextension_zlt.sqf: Error: ", _result, _returnCode, _errorCode, _command, _args];
};

if (
	_command isEqualTo ":VERSION:" &&
	_result isEqualType ""
) then {parseSimpleArray _result};
