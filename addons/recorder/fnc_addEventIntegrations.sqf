#include "script_component.hpp"

// remoteExec to all machines with JIP -- will trigger when local

{
  // log chat
	addMissionEventHandler ["HandleChatMessage", {
		params ["_channel", "_owner", "_from", "_text", "_person", "_name", "_strID", "_forcedDisplay", "_isPlayerMessage", "_sentenceType", "_chatMessageType"];
    if (!SHOULDSAVEEVENTS) exitWith {};

		if (_owner == clientOwner && parseNumber _strID > 1) then {
			_this remoteExecCall [QFUNC(handleChatMessage), 2];
		};
		false;
	}];
} remoteExec ["call", 0, true];

// ACE death
// https://github.com/acemod/ACE3/blob/c7e13ca4c7106ffb567b84b8590a472df4cab2f1/addons/medical_status/functions/fnc_setDead.sqf#L24-L27
// remoteExec to all machines with JIP -- is local event
{
  // need headless clients to register AI too, so we won't do an interface check
  if (isClass (configFile >> "CfgPatches" >> "ace_medical_status")) then {

    // add event handlers
    ["ace_medical_death", {
      if (!SHOULDSAVEEVENTS) exitWith {};
      _this params ["_unit"];
      _ownerId = _thisArgs;

      _ocapID = _unit getVariable [QGVARMAIN(id), -1];
      if (_ocapID isEqualTo -1) exitWith {};

      _lastDamageSource = _unit getVariable ["ace_medical_lastDamageSoruce", objNull];
      _lastDamageID = _lastDamageSource getVariable [QGVARMAIN(id), -1];

      [ // remoteExec back to server for session check
        [
          GVAR(captureFrameNo),
          _ocapID,
          _unit getVariable ["ace_medical_causeOfDeath", "UNKNOWN"],
          _lastDamageID
        ],
        {
          if (EGVAR(extension,sessionReady) && SHOULDSAVEEVENTS) then {
            [":ACE3:DEATH:", _this] call EFUNC(extension,sendData);
          };
        }
      ] remoteExec ["call", _ownerId];
    }, remoteExecutedOwner] call CBA_fnc_addEventHandlerArgs;
  };
} remoteExec ["call", 0, true];

// ace unconsciousness is a global event
// https://github.com/acemod/ACE3/blob/c7e13ca4c7106ffb567b84b8590a472df4cab2f1/addons/medical_status/functions/fnc_setUnconsciousState.sqf
if (isClass (configFile >> "CfgPatches" >> "ace_medical_status")) then {
  ["ace_unconscious", {
      if (!SHOULDSAVEEVENTS) exitWith {};
      _this params ["_unit", "_isUnconscious"];

      _ocapID = _unit getVariable [QGVARMAIN(id), -1];
      if (_ocapID isEqualTo -1) exitWith {};

      if (EGVAR(extension,sessionReady) && SHOULDSAVEEVENTS) then {
        [":ACE3:UNCONSCIOUS:", [
          GVAR(captureFrameNo),
          _ocapID,
          _isUnconscious
        ]] call EFUNC(extension,sendData);
      };
  }] call CBA_fnc_addEventHandlerArgs;
};


// remoteExec to all non-dedicated machines with JIP -- will trigger when local
{
  if (!hasInterface) exitWith {};

  // TFAR Beta support
  if (isClass (configFile >> "CfgPatches" >> "tfar_core")) then {
    ["TFAR_event_OnTangent", {
      _this params ["_TFAR_currentUnit", "_radio", "_radioType", "_additional", "_isStartTransmission"];
      _ownerId = _thisArgs;

      if (!SHOULDSAVEEVENTS) exitWith {};

      private [
        "_typeRadio",
        "_typeTransmission",
        "_channel",
        "_freq",
        "_code"
      ];

      _typeRadio = ["SW", "LR"] select _radioType;
      _typeTransmission = "Start";
      if (!_isStartTransmission) then {
        _typeTransmission = "Stop";
      };

      if (_typeRadio == "SW") then {
        if (!_additional) then {
          _radio = _radio call TFAR_fnc_activeSwRadio;
          _channel = _radio call TFAR_fnc_getSwChannel;
          _freq = [_radio, _channel + 1] call TFAR_fnc_getChannelFrequency;
          _code = _radio call TFAR_fnc_getSwRadioCode;
        } else {
          _radio = call TFAR_fnc_activeSwRadio;
          _channel = _radio call TFAR_fnc_getAdditionalSwChannel;
          // No Additional Channel set
          if (_channel < 0) exitWith {false};
          _freq = [_radio, _additionalChannel + 1] call TFAR_fnc_getChannelFrequency;
          _code = _radio call TFAR_fnc_getSwRadioCode;
        };
        // get the parent class of the radio wihtout numeric suffix that represents a unique radio
        _radio = getText(inheritsFrom (_radio call CBA_fnc_getItemConfig) >> "displayName");
      } else {
        if (!_additional) then {
          _radio = call TFAR_fnc_activeLrRadio;
          _channel = _radio call TFAR_fnc_getLrChannel;
          _freq = [_radio, _channel + 1] call TFAR_fnc_getChannelFrequency;
          _code = _radio call TFAR_fnc_getLrRadioCode;
        } else {
          _radio = call TFAR_fnc_activeLrRadio;
          _channel = _radio call TFAR_fnc_getAdditionalLrChannel;
          // No Additional Channel set
          if (_channel < 0) exitWith {false};
          _freq = [_radio, _additionalChannel + 1] call TFAR_fnc_getChannelFrequency;
          _code = _radio call TFAR_fnc_getLrRadioCode;
        };

        // LR and vehicle radios are sent as an array [obj, settings]
        private _actual = _radio#0;
        if ((_radio#0) isEqualType "") then {_radio = _radio#0} else {
          if ((_radio#0) isEqualType objNull) then {_radio = typeOf (_radio#0)};
        };
        // get display name
        _radio = getText(configFile >> "CfgVehicles" >> _radio >> "displayName");
      };

      // channels are returned on a 0 index, so fix that
      _channel = _channel + 1;
      // round frequency to the nearest 3 significant digits
      _freq = (parseNumber _freq) toFixed 3;

      [
          "TFAR", [
            _TFAR_currentUnit,
            _radio,
            _typeRadio,
            _typeTransmission,
            _channel,
            _additional,
            _freq,
            _code
          ]
      ] remoteExec [QFUNC(radioEvent), _ownerId];
    }, remoteExecutedOwner] call CBA_fnc_addEventHandlerArgs;
  };


  // ACRE2 support
  // wip
  // if (isClass (configFile >> "CfgPatches" >> "acre_main")) then {
  //   ["acre_startedSpeaking", {
          // if (!SHOULDSAVEEVENTS) exitWith {};
  //     _this params ["_unit", "_onRadio", "_radioId", "_speakingType"];
  //     if !(_onRadio) exitWith {};

  //     _ownerId = _thisArgs;

  // if (!(missionNamespace getVariable [QEGVAR(recorder,recording), false])) exitWith {};


  //     ["ACRE_PRC343_ID_1"] call acre_api_fnc_getDisplayName;
  //     diag_log format ["ACRE started speaking: %1 - %2 - %3", _this, _radioId, _speakingType];

  //     // _unitId = _unit call BIS_fnc_netId;
  //     // [_unitId, true] remoteExec [QFUNC(radioEvent), _ownerId];



  //   }, remoteExecutedOwner] call CBA_fnc_addEventHandlerArgs;

  //   ["acre_stoppedSpeaking", {
  //     _this params ["_unit", "_onRadio"];
  //     if !(_onRadio) exitWith {};

  //     _ownerId = _thisArgs;
  //     TRACE_1("ACRE stopped speaking", _this);

  //     // _unitId = _unit call BIS_fnc_netId;
  //     // [_unitId, false] remoteExec [QFUNC(radioEvent), _ownerId];

  //     _unit setVariable [QGVARMAIN(isSpeakingRadio), false, _ownerId];
  //   }, remoteExecutedOwner] call CBA_fnc_addEventHandlerArgs;
  // };

  missionNamespace setVariable [QGVARMAIN(radioEventsInitialized), true];
} remoteExec ["call", [0, -2] select isDedicated, true];
