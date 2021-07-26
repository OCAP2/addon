#include "\userconfig\ocap\config.hpp"
#include "script_macros.hpp"

ocap_capture = false;
ocap_captureFrameNo = 0;
ocap_needToSave = [false, true] select (ocap_minMissionTime < 10);

if (ocap_excludeMarkerFromRecord isEqualType []) then {
	publicVariable "ocap_excludeMarkerFromRecord";
} else {
	LOG(["excludeMarkerFromRecord in config is not an array, skipping exclusions"]);
};

ocap_addon_ver = OCAP_ADDON_VERSION;
publicVariable ocap_addon_ver;

{
	player createDiarySubject ["OCAP2Info", "OCAP2", "\A3\ui_f\data\igui\cfg\simpleTasks\types\whiteboard_ca.paa"];

	ocap_fnc_copyGitHubToClipboard = {copyToClipboard "https://github.com/OCAP2/OCAP"; systemChat "OCAP2 GitHub link copied to clipboard";};
	ocap_diaryAbout = player createDiaryRecord [
		"OCAP2Info",
		[
			"About",
			(
				"OCAP2<br/>" +
				"Addon version: " + ocap_addon_ver +
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
} remoteExecCall ["call", 0, true];
{
	ocap_diaryStatus = player createDiaryRecord [
		"OCAP2Info",
		[
			"Status",
			"OCAP2 initialized. Awaiting capture conditions to be met."
		]
	];
} remoteExecCall ["call", 0, false];

// Add event missions
call ocap_fnc_addEventMission;
[":START:", [worldName, briefingName, getMissionConfigValue ["author", ""], ocap_frameCaptureDelay]] call ocap_fnc_extension;
0 spawn ocap_fnc_startCaptureLoop;

0 spawn {
	if (ocap_needToSave) exitWith {};
	LOG(["Waiting freeze end!"]);
	waitUntil {sleep 1.4; missionNamespace getVariable["WMT_pub_frzState", 3] >= 3};
	LOG(["Waiting until ocap_minMissionTime ends"]);
	sleep ocap_minMissionTime;
	LOG(["ocap_needToSave is set to true"]);
	ocap_needToSave = true;
};
