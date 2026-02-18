class CfgPatches
{
  class ocap_translations
  {
    requiredVersion = 2.06;
    name = "OCAP - Translations";
    author = "OCAP2 Team";
    url = "https://github.com/OCAP2/OCAP";
    requiredAddons[] = {"cba_settings"};
    units[] = {};
    weapons[] = {};
  };
};

class Extended_PreInit_EventHandlers
{
  class ocap_translations
  {
    init = "call compile preprocessFileLineNumbers '\x\ocap\addons\translations\XEH_preInit.sqf'";
  };
};
