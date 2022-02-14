/* ----------------------------------------------------------------------------
Script: ocap_fnc_init

Description:
	Run during preInit and used to start OCAP2 processes.

Parameters:
	None

Returns:
	Nothing

Examples:
	--- Code
	call ocap_fnc_init;
	---

Public:
	No

Author:
	Dell, Zealot, IndigoFox
---------------------------------------------------------------------------- */

#include "\userconfig\ocap\config.hpp"
#include "script_macros.hpp"

// bool: ocap_capture
ocap_capture = false;
// int: ocap_captureFrameNo
ocap_captureFrameNo = 0;
// bool: ocap_needToSave
ocap_needToSave = [false, true] select (ocap_minMissionTime < 10);

if (ocap_excludeMarkerFromRecord isEqualType []) then {
	publicVariable "ocap_excludeMarkerFromRecord";
} else {
	LOG(["excludeMarkerFromRecord in config is not an array, skipping exclusions"]);
};

// macro: OCAP_ADDON_VERSION
ocap_addon_ver = OCAP_ADDON_VERSION;
publicVariable "ocap_addon_ver";

ocap_extension_ver = ([":VERSION:", []] call ocap_fnc_extension);
publicVariable "ocap_extension_ver";


{
	[{!isNil "ocap_addon_ver" && !isNil "ocap_extension_ver"}, {
		player createDiarySubject ["OCAP2Info", "OCAP2 AAR", "\A3\ui_f\data\igui\cfg\simpleTasks\types\whiteboard_ca.paa"];

		ocap_fnc_copyGitHubToClipboard = {copyToClipboard "https://github.com/OCAP2/OCAP"; systemChat "OCAP2 GitHub link copied to clipboard";};
		ocap_diaryAbout = player createDiaryRecord [
			"OCAP2Info",
			[
				"About",
				(
					"<font size='20' face='PuristaBold'><font color='#BBBBBB'>OCAP</font><font color='#44AAFF'>2</font></font><br/>" +
					"Addon version: " + ocap_addon_ver +
					"<br/>" +
					"Extension version: " + (ocap_extension_ver # 0) + " (built " + (ocap_extension_ver # 1) + ")" +
					"<br/>" +
					"<execute expression='call ocap_fnc_copyGitHubToClipboard;'>https://github.com/OCAP2/OCAP</execute>" +
					"<br/><br/>" +
					"OCAP2 is a server-side Arma 3 recording suite that provides web-based playback of all units, vehicles, markers, and projectiles present, placed, and fired during a mission." +
					"<br/><br/>" +
					"Recording status can be found in the Status section." +
					"<br/><br/>" +
					"DISCLAIMER: This mission may be recorded and made publicly available at the discretion of the server administrators. Please be aware that your actions during this mission will be tracked and attributed to your in-game username."
				)
			]
		];

		ocap_diaryStatus = player createDiaryRecord [
			"OCAP2Info",
			[
				"Status",
				"OCAP2 initialized. Awaiting configured capture conditions."
			]
		];
	}] call CBA_fnc_waitUntilAndExecute;
} remoteExecCall ["call", 0, true];

// Support both methods of setting mission name.
ocap_missionName = getMissionConfigValue ["onLoadName", ""];
if (ocap_missionName == "") then {
    ocap_missionName = briefingName;
};

// Add event missions
call ocap_fnc_addEventMission;
[":START:", [worldName, ocap_missionName, getMissionConfigValue ["author", ""], ocap_frameCaptureDelay]] call ocap_fnc_extension;
0 spawn ocap_fnc_startCaptureLoop;

[":SET:VERSION:", [OCAP_ADDON_VERSION]] call ocap_fnc_extension;

0 spawn {
	if (ocap_needToSave) exitWith {};
	LOG(["Waiting freeze end!"]);
	waitUntil {sleep 1.4; missionNamespace getVariable["WMT_pub_frzState", 3] >= 3};
	LOG(["Waiting until ocap_minMissionTime ends"]);
	sleep ocap_minMissionTime;
	LOG(["ocap_needToSave is set to true"]);
	ocap_needToSave = true;
};
