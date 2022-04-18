#include "script_component.hpp"

params ["_PID"];

if (isNil "_PID") exitWith {};

(getUserInfo _PID) params ["_playerID", "_owner", "_playerUID"];

// check if admin
private _adminUIDs = missionNamespace getVariable [QGVARMAIN(administratorList), nil];

if (isNil "_adminUIDs") then {
  _adminUIDs = parseSimpleArray QGVARMAIN(administratorList);
};
if (isNil "_adminUIDs") exitWith {
  WARNING("Failed to parse administrator list setting. Please check its value!");
};

if !(_playerUID in _adminUIDs) exitWith {};


// add controls to diary entry
{
  [{getClientStateNumber > 9 && !isNull player}, {

    if (player getVariable [QGVARMAIN(hasAdminControls), false]) exitWith {};

    EGVAR(diary,adminControls) = player createDiarySubject [
      QEGVAR(diary,adminControls_subject),
      PREFIX + " Admin",
      "\A3\ui_f\data\igui\cfg\simpleTasks\types\interact_ca.paa"
    ];

    player createDiaryRecord [
      QEGVAR(diary,adminControls_subject),
      [
        PREFIX + " Controls",
        "<br/>
  <execute expression='[" + QGVARMAIN(record) + "] call CBA_fnc_serverEvent;'>Start/Resume Recording</execute><br/>
  <execute expression='[" + QGVARMAIN(pause) + "] call CBA_fnc_serverEvent;'>Pause Recording</execute><br/>
  <execute expression='[" + QGVARMAIN(exportData) + "] call CBA_fnc_serverEvent;'>Stop and Export Recording</execute>
    "
      ]
    ];

    player setVariable [QGVARMAIN(hasAdminControls), true, 2];
  }] call CBA_fnc_waitUntilAndExecute;
} remoteExec ["call", _owner];
