/* ----------------------------------------------------------------------------
FILE: fnc_addEventMission.sqf

FUNCTION: OCAP_recorder_fnc_addEventMission

Description:
  Used for applying mission event handlers. Applied during initialization of OCAP in <OCAP_recorder_fnc_init>.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(addEventMission);

Public:
  No

Author:
  IndigoFox, Dell
---------------------------------------------------------------------------- */
#include "script_component.hpp"

// Section: Event Handlers

if (isNil QEGVAR(EH,HandleDisconnect)) then {
  // Event Handler: OCAP_EH_HandleDisconnect
  // Fired when a player leaves the mission by returning to lobby or disconnecting. Calls <OCAP_recorder_fnc_eh_disconnected>.
  EGVAR(EH,HandleDisconnect) = addMissionEventHandler["HandleDisconnect", {
    _this call FUNC(eh_disconnected);
    false; // ensure we're not overriding disabledAI and persisting an AI unit to replace the player's
  }];
  OCAPEXTLOG(["Initialized HandleDisconnect EH"]);
};

if (isNil QEGVAR(EH,PlayerConnected)) then {
  // Event Handler: OCAP_EH_PlayerConnected
  // Handle for the "PlayerConnected" mission event handler. Fired when a player joins the mission from lobby and appears in the world. Calls <OCAP_recorder_fnc_eh_connected>.
  EGVAR(EH,PlayerConnected) = addMissionEventHandler["PlayerConnected", {
    _this call FUNC(eh_connected);
  }];
  OCAPEXTLOG(["Initialized PlayerConnected EH"]);
};

if (isNil QEGVAR(EH,OnUserAdminStateChanged)) then {
  // Event Handler: OCAP_EH_OnUserAdminStateChanged
  // Handle for the "OnUserAdminStateChange" mission event handler. Fired when a player's admin status changes. Calls <OCAP_recorder_fnc_eh_onUserAdminStateChanged>.
  EGVAR(EH,OnUserAdminStateChanged) = addMissionEventHandler ["OnUserAdminStateChanged", {
    _this call FUNC(eh_onUserAdminStateChanged);
  }];
  OCAPEXTLOG(["Initialized OnUserAdminStateChanged EH"]);
};

if (isNil QEGVAR(EH,EntityKilled)) then {
  // Event Handler: OCAP_EH_EntityKilled
  // Handle for the "EntityKilled" mission event handler. Fired when an entity is killed. Calls <OCAP_recorder_fnc_eh_killed>.
  EGVAR(EH,EntityKilled) = addMissionEventHandler ["EntityKilled", {
    _this call FUNC(eh_killed);
  }];
  OCAPEXTLOG(["Initialized EntityKilled EH"]);
};

if (isNil QEGVAR(EH,EntityRespawned)) then {
  // Event Handler: OCAP_EH_EntityRespawned
  // Handle for the "EntityRespawned" mission event handler. Fired when an entity is respawned. Sets new body to not-killed and calls <OCAP_recorder_fnc_addUnitEventHandlers> on it. Then excludes corpse from further capture.
  EGVAR(EH,EntityRespawned) = addMissionEventHandler ["EntityRespawned", {
    params ["_entity", "_corpse"];

    // Reset unit back to normal
    _entity setvariable [QGVARMAIN(isKilled), false];

    // Stop tracking old unit
    if (_corpse getVariable [QGVARMAIN(isInitialized), false]) then {
      _corpse setVariable [QGVARMAIN(exclude), true];

      [_entity, true] spawn FUNC(addUnitEventHandlers);
    };
  }];
  OCAPEXTLOG(["Initialized EntityRespawned EH"]);
};


if (isNil QEGVAR(EH,MPEnded)) then {
  // Event Handler: OCAP_EH_MPEnded
  // Handle for the "MPEnded" mission event handler. Fired on the MPEnded mission event. This is used to automatically save and export if <OCAP_settings_saveMissionEnded> is true and <OCAP_settings_minMissionTime> was reached.
  EGVAR(EH,MPEnded) = addMissionEventHandler ["MPEnded", {
    if (EGVAR(settings,saveMissionEnded) && (GVAR(captureFrameNo) * GVAR(frameCaptureDelay)) >= GVAR(minMissionTime)) then {
      ["Mission ended automatically"] call FUNC(exportData);
    };
  }];
  OCAPEXTLOG(["Initialized MPEnded EH"]);
};

if (isNil QEGVAR(EH,Ended)) then {
  // Event Handler: OCAP_EH_Ended
  // Handle for the "Ended" mission event handler. Fired on the singleplayer Ended mission event. This is used to automatically save and export if <OCAP_settings_saveMissionEnded> is true and <OCAP_settings_minMissionTime> was reached. Kept in just in case this event triggers.
  EGVAR(EH,Ended) = addMissionEventHandler ["Ended", {
    if (EGVAR(settings,saveMissionEnded) && (GVAR(captureFrameNo) * GVAR(frameCaptureDelay)) >= GVAR(minMissionTime)) then {
      ["Mission ended automatically"] call FUNC(exportData);
    };
  }];
  OCAPEXTLOG(["Initialized Ended EH"]);
};


// Add event saving markers
if (isNil QEGVAR(listener,markers)) then {
  call FUNC(handleMarkers);
};



// Section: CBA Events

/*
  Variables: CBA Listener Handles

  OCAP_listener_aceThrowing - Handle for <ace_advanced_throwing_throwFiredXEH> listener.
  OCAP_listener_aceExplosives - Handle for <ace_explosives_place> listener.
  OCAP_listener_customEvent - Handle for <OCAP_customEvent> listener.
  OCAP_listener_counterInit - Handle for <OCAP_counterInit> listener.
  OCAP_listener_counterEvent - Handle for <OCAP_counterEvent> listener.
  OCAP_counter_sides - Sides that are tracked by the custom counter system. [Array]
  OCAP_listener_record - Handle for <OCAP_record> listener.
  OCAP_listener_pause - Handle for <OCAP_pause> listener.
  OCAP_listener_exportData - Handle for <OCAP_exportData> listener.
*/


if (isClass (configFile >> "CfgPatches" >> "ace_advanced_throwing")) then {
  if (isNil QEGVAR(listener,aceThrowing)) then {
    /*
      CBA Event: ace_advanced_throwing_throwFiredXEH
      Fired when a throwable is primed. This is a global event the server will handle and forward to <OCAP_recorder_fnc_eh_firedMan>. Created only if PBO "ace_advanced_throwing" is loaded.
    */
    EGVAR(listener,aceThrowing) = ["ace_advanced_throwing_throwFiredXEH", {
      _this call FUNC(eh_firedMan)
    }] call CBA_fnc_addEventHandler;
    OCAPEXTLOG(["Initialized ACE Throwing listener"]);
  };
};

if (isClass (configFile >> "CfgPatches" >> "ace_explosives")) then {
  if (isNil QEGVAR(listener,aceExplosives)) then {
    /*
      CBA Event: ace_explosives_place
      Event listener for ACE3 global event indicating a mine has been placed and armed. Calls <OCAP_recorder_fnc_aceExplosives> when triggered. Created only if PBO "ace_explosives" is loaded.
    */
    EGVAR(listener,aceExplosives) = ["ace_explosives_place", {
      call FUNC(aceExplosives);
    }] call CBA_fnc_addEventHandler;
    OCAPEXTLOG(["Initialized ACE Explosives listener"]);
  };
};


/*
  CBA Event: OCAP_customEvent
  Description:
    Event listener for custom event text to be added to the timeline. Calls <OCAP_recorder_fnc_handleCustomEvent> when triggered.

  Parameters:
    0 - Event name [String]
    1 - Event data [Array]
      1.0 - Always "generalEvent" [String]
      1.1 - Custom event text [String]

  Example:
    > ["OCAP_customEvent", ["generalEvent", "The warehouse has been secured!"]] call CBA_fnc_serverEvent;
    > [QGVARMAIN(customEvent), ["generalEvent", "The warehouse has been secured!"]] call CBA_fnc_serverEvent;

*/
if (isNil QEGVAR(listener,customEvent)) then {
  EGVAR(listener,customEvent) = [QGVARMAIN(customEvent), {
    _this call FUNC(handleCustomEvent);
  }] call CBA_fnc_addEventHandler;
  OCAPEXTLOG(["Initialized customEvent listener"]);
};

/*
  CBA Event: OCAP_counterInit
  Description:
    Meant for use in custom tracking of points or score between two sides. Separate from BIS_fnc_respawnTickets. Initializes the system. Calls <OCAP_recorder_fnc_counterInit> when triggered.

  Parameters:
    0 - Event name [String]
    1 - Key/value for one or more sides [Array]
      1.0 - Pair [Array]
        1.0.0 - Side <SIDE>
        1.0.1 - Initial value [Number]

  Example:
    (start code)
    ["OCAP_counterInit", [
      [west, 0],
      [east, 0]
    ]] call CBA_fnc_serverEvent;

    [QGVARMAIN(counterInit), [
      [west, 0],
      [east, 0]
    ]] call CBA_fnc_serverEvent;
    (end code)
*/
if (isNil QEGVAR(listener,counterInit)) then {
  EGVAR(listener,counterInit) = [QGVARMAIN(counterInit), {
    EGVAR(counter,sides) = _this apply {_x#0};
    [QGVARMAIN(customEvent), ["counterInit", EGVAR(counter,sides)]] call CBA_fnc_localEvent;
    {
      [QGVARMAIN(counterEvent), _x] call CBA_fnc_serverEvent;
    } forEach _this;
    [_thisType, _thisId] call CBA_fnc_removeEventHandler;
  }] call CBA_fnc_addEventHandlerArgs;
  OCAPEXTLOG(["Initialized counterInit listener"]);
};

/*
  CBA Event: OCAP_counterEvent
  Description:
    Meant for use in custom tracking of points or score between two sides. Separate from BIS_fnc_respawnTickets. Updates the system. Calls <OCAP_recorder_fnc_counterEvent> when triggered.

  Parameters:
    0 - Event name [String]
    1 - Event data [Array]
      1.0 - Side <SIDE>
      1.1 - Value to set [Number]

  Example:
    > ["OCAP_counterEvent", [west, 1]] call CBA_fnc_serverEvent;
*/
if (isNil QEGVAR(listener,counterEvent)) then {
  EGVAR(listener,counterEvent) = [QGVARMAIN(counterEvent), {
    if (isNil QEGVAR(counter,sides)) exitWith {};
    if (typeName (_this#0) != "SIDE") exitWith {};
    if !((_this#0) in EGVAR(counter,sides)) exitWith {};

    private _scores = [];
    {
      if ((_this#0) isEqualTo _x) then {_scores pushBack (_this#1)};
    } forEach EGVAR(counter,sides);
    [QGVARMAIN(customEvent), ["counterSet", _scores]] call CBA_fnc_localEvent;
  }] call CBA_fnc_addEventHandler;
  OCAPEXTLOG(["Initialized counterEvent listener"]);
};

/*
  CBA Event: OCAP_record
  Description:
    Used to start or resume recording. Calls <OCAP_recorder_fnc_startRecording> when triggered.

  Example:
    > ["OCAP_record"] call CBA_fnc_serverEvent;
*/
if (isNil QEGVAR(listener,record)) then {
  EGVAR(listener,record) = [QGVARMAIN(record), {
    call FUNC(startRecording);
  }] call CBA_fnc_addEventHandler;
  OCAPEXTLOG(["Initialized record listener"]);
};

/*
  CBA Event: OCAP_pause
  Description:
    Used to pause recording. Calls <OCAP_recorder_fnc_stopRecording> when triggered.

  Example:
    > ["OCAP_pause"] call CBA_fnc_serverEvent;
*/
if (isNil QEGVAR(listener,pause)) then {
  EGVAR(listener,pause) = [QGVARMAIN(pause), {
    call FUNC(stopRecording);
  }] call CBA_fnc_addEventHandler;
  OCAPEXTLOG(["Initialized pause listener"]);
};

/*
  CBA Event: OCAP_exportData
  Description:
    Used to stop recording & signal the extension to save and upload it to the web component. Calls <OCAP_recorder_fnc_exportData> when triggered.

    *Will always bypass <OCAP_settings_minMissionTime>*.

  Parameters:
    0 - Event name [String]
    1 - Event data [Array]
      1.0 - (optional) Winning side <SIDE>
      1.1 - (optional) Message describing mission end [String]
      1.2 - (optional) Custom save tag (overrides <OCAP_settings_saveTag>) [String]
*/
if (isNil QEGVAR(listener,exportData)) then {
  EGVAR(listener,exportData) = [QGVARMAIN(exportData), {
    _this set [3, true];
    _this call FUNC(exportData);
  }] call CBA_fnc_addEventHandler;
  OCAPEXTLOG(["Initialized exportData listener"]);
};
