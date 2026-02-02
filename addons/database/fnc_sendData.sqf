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

// Helper function to parse and unwrap response
private _parseResponse = {
  params ["_result", "_returnCode", "_errorCode", "_command"];

  if (_errorCode != 0 || _returnCode != 0) exitWith {
    diag_log text format ["[OCAP] [DB-EXT] ERROR when calling extension: returnCode=%1, errorCode=%2", _returnCode, _errorCode];
    nil
  };

  if (_result isEqualTo "") exitWith {
    diag_log text "[OCAP] [DB-EXT] WARNING: Empty response from extension";
    nil
  };

  // Handle raw values (not array format) - e.g., :TIMESTAMP: returns raw number
  if !(_result select [0, 1] isEqualTo "[") exitWith {
    diag_log text format ["[OCAP] [DB-EXT] Raw response: %1", _result];
    _result
  };

  private _parsed = parseSimpleArray _result;
  diag_log text format ["[OCAP] [DB-EXT] Parsed response: %1", _parsed];

  if !(_parsed isEqualType []) exitWith {
    diag_log text format ["[OCAP] [DB-EXT] ERROR: Response is not an array: %1", _parsed];
    nil
  };

  if (count _parsed < 2) exitWith {
    diag_log text format ["[OCAP] [DB-EXT] ERROR: Response array too short: %1", _parsed];
    nil
  };

  private _status = _parsed # 0;
  private _data = _parsed # 1;

  if (_status isEqualTo "error") exitWith {
    diag_log text format ["[OCAP] [DB-EXT] ERROR from extension: %1 (command: %2)", _data, _command];
    nil
  };

  if (_status isEqualTo "ok") exitWith {
    diag_log text format ["[OCAP] [DB-EXT] OK: %1", _data];
    _data
  };

  // Unknown status, return data as-is
  _data
};

if (_args isEqualType []) exitWith {
  diag_log text format ["[OCAP] [DB-EXT] >> Calling extension '%1' with command='%2', args=%3", _dllName, _command, _args];

  private _res = _dllName callExtension [_command, _args];
  _res params ["_result","_returnCode","_errorCode"];

  diag_log text format ["[OCAP] [DB-EXT] << Response: result='%1', returnCode=%2, errorCode=%3", _result, _returnCode, _errorCode];

  [_result, _returnCode, _errorCode, _command] call _parseResponse
};

if (isNil "_args") exitWith {
  diag_log text format ["[OCAP] [DB-EXT] >> Calling extension '%1' with command='%2' (no args)", _dllName, _command];

  private _res = _dllName callExtension _command;

  diag_log text format ["[OCAP] [DB-EXT] << Response: '%1'", _res];

  [_res, 0, 0, _command] call _parseResponse
};
