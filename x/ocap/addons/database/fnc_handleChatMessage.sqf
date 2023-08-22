#include "script_component.hpp"

params ["_channel", "_owner", "_from", "_text", "_person", "_name", "_strID", "_forcedDisplay", "_isPlayerMessage", "_sentenceType", "_chatMessageType"];

private _playerUID = "";
if (parseNumber _strID > 1) then {
  private _getUserInfo = getUserInfo _strID;
  if (!isNil "_getUserInfo" && {count _getUserInfo >= 3}) then {
    _playerUID = _getUserInfo#2;
  };
};

private _senderOcapId = _person getVariable [QGVARMAIN(id), -1];

[":CHAT:", [
  EGVAR(recorder,captureFrameNo),
  _senderOcapId,
  _channel,
  _from,
  _name,
  _text,
  _playerUID
]] call FUNC(sendData);
