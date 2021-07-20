////////////////////////////////////////////////////////////////////
//DeRap: ocap\config.bin
//Produced from mikero's Dos Tools Dll version 8.02
//https://mikero.bytex.digital/Downloads
//'now' is Sun Apr 25 20:52:44 2021 : 'file' last modified on Tue Mar 16 12:25:11 2021
////////////////////////////////////////////////////////////////////

#define _ARMA_

class CfgPatches
{
	class OCAP
	{
		name = "OCAP";
		author = "Dell, Zealot, Kurt, IndigoFox";
		requiredAddons[] = {"A3_Functions_F","cba_main"};
		requiredVersion = 2.4;
		units[] = {};
		weapons[] = {};
	};
};
class CfgFunctions
{
	class OCAP
	{
		class null
		{
			file = "ocap\functions";
			class init
			{
				preInit = 1;
			};
			class addEventHandlers{};
			class addEventMission{};
			class eh_connected{};
			class eh_disconnected{};
			class eh_fired{};
			class eh_hit{};
			class eh_killed{};
			class exportData{};
			class extension{};
			class getDelay{};
			class getInstigator{};
			class getUnitType{};
			class handleMarkers{};
			class startCaptureLoop{};
			class trackAceExplLife{};
			class trackAceExplPlace{};
			class trackAceRemoteDet{};
			class trackAceThrowing{};
			class updateTime{};
		};
	};
};

class CfgRemoteExec
{
	class Functions
	{
		class ocap_fnc_handleMarkers
		{
			allowedTargets = 2;
		};
		class trackAceThrowing{
			allowedTargets = 0;
		};
	};
};
