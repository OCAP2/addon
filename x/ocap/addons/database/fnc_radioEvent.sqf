#include "script_component.hpp"

// process radio events
// this function will be remote executed by clients when local CBA events trigger

params [
  ["_mod", "", [""]],
  ["_data", [], [[]]]
];

if (_mod isEqualTo "" || _data isEqualTo []) exitWith {};

if (_mod isEqualTo "TFAR") then {
  _data params [
    ["_unit", objNull, [objNull]],
    ["_radio", "", ["", []]],
    ["_typeRadio", "", [""]],
    ["_typeTransmission", "", [""]],
    "_channel",
    ["_isAdditional", false, [false]],
    "_freq",
    "_code"
  ];

  private _ocapId = _unit getVariable [QGVARMAIN(id), -1];
  if (
    _ocapId isEqualTo -1 ||
    _channel isEqualTo -1 ||
    _freq isEqualTo -1
  ) exitWith {};

  [
    ":RADIO:", [
      EGVAR(recorder,captureFrameNo),
      _ocapId,
      _radio,
      _typeRadio,
      _typeTransmission,
      _channel,
      _isAdditional,
      _freq,
      _code
    ]
  ] call FUNC(sendData);
};
