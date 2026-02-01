/* ----------------------------------------------------------------------------
FILE: fnc_sendData.sqf

FUNCTION: OCAP_database_fnc_sendData

Description:
	Manages raw extension calls and returns values / logs errors where relevant.

Parameters:
	_command - The extension command to call [String]
	_args - The arguments to send [Array]

Returns:
	Depends

Examples:
	> [":VERSION", []] call EFUNC(database,sendData);

Public:
	No

Author:
	Dell, Zealot, modified by IndigoFox
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_command","_args", ["_dllName", "ocap_recorder"]];

if (_args isEqualType []) exitWith {
  diag_log text format ["[OCAP] [DB-EXT] >> Calling extension '%1' with command='%2', args=%3", _dllName, _command, _args];

  private _res = _dllName callExtension [_command, _args];

  _res params ["_result","_returnCode","_errorCode"];

  diag_log text format ["[OCAP] [DB-EXT] << Response: result='%1', returnCode=%2, errorCode=%3", _result, _returnCode, _errorCode];

  if (_errorCode != 0 || _returnCode != 0) then {
    diag_log text format ["[OCAP] [DB-EXT] ERROR: %1", [_result, _returnCode, _errorCode, _command, _args]];
  };
};

if (isNil "_args") exitWith {
  diag_log text format ["[OCAP] [DB-EXT] >> Calling extension '%1' with command='%2' (no args)", _dllName, _command];
  private _res = _dllName callExtension _command;
  diag_log text format ["[OCAP] [DB-EXT] << Response: '%1'", _res];
  _res
};


// if (
// 	_result isEqualType ""
// // ) then {parseSimpleArray _result};
// ) then {diag_log text format ["%1", _result];};
