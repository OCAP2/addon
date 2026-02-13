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

if (_returnCode != 0) exitWith {
  diag_log text format ["[OCAP] [EXT] ERROR from extension (returnCode=%1): %2", _returnCode, [_result, _returnCode, _errorCode, _command, _args]];
  nil
};

if (_errorCode != 0) then {
  diag_log text format ["[OCAP] [EXT] WARNING: Arma errorCode=%1 for command '%2' (result still valid)", _errorCode, _command];
};

// Parse the response - new format: ["ok", <result>] or ["error", "<message>"]
if (_result isEqualTo "") exitWith {
  diag_log text "[OCAP] [EXT] WARNING: Empty response from extension";
  nil
};

private _parsed = parseSimpleArray _result;
diag_log text format ["[OCAP] [EXT] Parsed response: %1", _parsed];

if !(_parsed isEqualType []) exitWith {
  diag_log text format ["[OCAP] [EXT] ERROR: Response is not an array: %1", _parsed];
  nil
};

if (count _parsed < 1) exitWith {
  diag_log text format ["[OCAP] [EXT] ERROR: Response array empty: %1", _parsed];
  nil
};

private _status = _parsed # 0;

if (_status isEqualTo "error") exitWith {
  private _errorMsg = if (count _parsed > 1) then {_parsed # 1} else {"Unknown error"};
  diag_log text format ["[OCAP] [EXT] ERROR from extension: %1 (command: %2)", _errorMsg, _command];
  nil
};

if (_status isEqualTo "ok") exitWith {
  if (count _parsed > 1) then {
    private _data = _parsed # 1;
    diag_log text format ["[OCAP] [EXT] OK: %1", _data];
    _data
  } else {
    diag_log text "[OCAP] [EXT] OK";
    true
  };
};

// Unknown status
diag_log text format ["[OCAP] [EXT] Unknown status: %1", _status];
nil
