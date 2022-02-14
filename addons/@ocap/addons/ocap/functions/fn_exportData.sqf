/* ----------------------------------------------------------------------------
Script: ocap_fnc_exportData

Description:
	This function facilitates the actual endMission and save events in the extension, prompting it to pack the mission and upload it to the web component.

	This function MUST be called in order to save a mission recording. A boolean true in the correct option of userconfig.hpp will automatically execute this function when the "MPEnded" Event Handler triggers.

Parameters:
	_side - The winning side [optional, Side]
	_message - A custom description of how the victory was achieved [optional, String]
	_tag - A custom tag to override that which is defined in userconfig.hpp that will make it filterable in web [optional, String]

Returns:
	Nothing

Examples:
	--- Code
	// "Mission ended"
	[] call ocap_fnc_exportData;

	// "BLUFOR Win."
	[west] call ocap_fnc_exportData;

	// "OPFOR Win. OPFOR controlled all sectors!
	[east, "OPFOR controlled all sectors!"] call ocap_fnc_exportData;

	// "Independent Win. INDFOR stole the intel!"
	// Mission is saved under filterable "SnatchAndGrab" tag on web
	[independent, "INDFOR stole the intel!", "SnatchAndGrab"] call ocap_fnc_exportData;
	---

Public:
	Yes

Author:
	Dell, Zealot, IndigoFox, TyroneMF
---------------------------------------------------------------------------- */

#include "script_macros.hpp"
if (!ocap_capture) exitWith {LOG(["fnc_exportData.sqf called, but recording hasn't started."]);};

[] spawn {
	_realyTime = time - ocap_startTime;
	_ocapTime = ocap_frameCaptureDelay * ocap_captureFrameNo;
	LOG(ARR6("fnc_exportData.sqf: RealyTime =", _realyTime," OcapTime =", _ocapTime," delta =", _realyTime - _OcapTime));
};

ocap_capture = false;
ocap_endFrameNo = ocap_captureFrameNo;

publicVariable "ocap_endFrameNo";

params ["_side", "_message", "_tag"];
switch (count _this) do {
	case 0: {
		[":EVENT:", [ocap_endFrameNo, "endMission", ["", "Mission ended"]]] call ocap_fnc_extension;
	};
	case 1: {
		[":EVENT:", [ocap_endFrameNo, "endMission", ["", _side]]] call ocap_fnc_extension;
	};
	default {
		private _sideString = str(_side);
		if (_side == sideUnknown) then { _sideString = "" };
		[":EVENT:", [ocap_endFrameNo, "endMission", [_sideString, _message]]] call ocap_fnc_extension;
	};
};

if (ocap_needToSave) then {
	if (!isNil "_tag") then {
		[":SAVE:", [worldName, ocap_missionName, getMissionConfigValue ["author", ""], ocap_frameCaptureDelay, ocap_endFrameNo, _tag]] call ocap_fnc_extension;
		LOG(ARR4("Saved recording of mission", ocap_missionName, "with tag", _tag));
	} else {
		[":SAVE:", [worldName, ocap_missionName, getMissionConfigValue ["author", ""], ocap_frameCaptureDelay, ocap_endFrameNo]] call ocap_fnc_extension;
		LOG(ARR3("Saved recording of mission", ocap_missionName, "with default tag"));
	};

	// briefingName is used here, no need for publicVariable for a simple confirmation log.
	{
		player createDiaryRecord [
			"OCAP2Info",
			[
				"Status",
				(
					"<font color='#33FF33'>OCAP2 capture of " + briefingName + " has been exported with " + str(ocap_endFrameNo) + " frames saved.</font>" +
					"<br/><br/>" +
					"Upload results have been logged."
				)
			]
		];
		player setDiarySubjectPicture [
			"OCAP2Info",
			"\A3\ui_f\data\igui\cfg\simpleTasks\types\upload_ca.paa"
		];
	} remoteExec ["call", 0, false];
} else {
	LOG(["ocap_needToSave is set to false. Not saving"]);
	{
		player createDiaryRecord [
			"OCAP2Info",
			[
				"Status",
				(
					"<font color='#FFFF33'>OCAP2 capture of " + briefingName + " has not been saved, as the configured criteria have not been met.</font>"
				)
			]
		];
		player setDiarySubjectPicture [
			"OCAP2Info",
			"\A3\ui_f\data\igui\cfg\simpleTasks\types\danger_ca.paa"
		];
	} remoteExec ["call", 0, false];
};
