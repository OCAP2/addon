/* ----------------------------------------------------------------------------
Script: EFUNC(extension,sendData)

Description:
	Manages raw extension calls and returns values / logs errors where relevant.

Parameters:
	_command - The extension command to call [String]
	_args - The arguments to send [Array]

Returns:
	Depends

Examples:
	--- Code
	[":VERSION", []] call EFUNC(extension,sendData);
	---

Public:
	No

Author:
	Dell, Zealot
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params [["_data", [], ["", []]]];

///////////////////////////////////////////////
// Send to debug_console/Macro

// private "_success";
// switch (typeName _data) do {
//   case "STRING": {
//     ACMI(_data);
//     _success = true;
//   };
//   case "ARRAY": {
//     if (count _data == 0) exitWith {diag_log format["%1 > %2: improper data", _fnc_scriptNameParent, _fnc_scriptName]};
//     _r = _data joinString EOL;
//     ACMI(_r);
//     _success = false;
//   };
// };

// _success;


///////////////////////////////////////////////
// Save to giant array for all at once output
private _success = false;
switch (typeName _data) do {
  case "STRING": {
    GVAR(recordingData) pushBack _data;
    _success = true;
  };
  case "ARRAY": {
    if (count _data == 0) exitWith {diag_log format["%1 > %2: improper data", _fnc_scriptNameParent, _fnc_scriptName]};
    _r = _data joinString EOL;
    GVAR(recordingData) pushBack _r;
    _success = true;
  };
};

_success;






///////////////////////////////////

// params ["_command","_args"];

// private _dllName = "OcapReplaySaver2";

// private _res = _dllName callExtension [_command, _args];

// _res params ["_result","_returnCode","_errorCode"];

// if (_errorCode != 0 || _returnCode != 0) then {
//   textLogFormat ["Error when calling extension: %1", [_result, _returnCode, _errorCode, _command, _args]];
// };

// if (
// 	_command isEqualTo ":VERSION:" &&
// 	_result isEqualType ""
// ) then {parseSimpleArray _result};


// _r = _data joinString (toString [0x0A])
// "debug_console" callExtension ((_r) + "~0000");
