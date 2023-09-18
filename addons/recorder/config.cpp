#define _ARMA_
#include "script_component.hpp"

class CfgPatches
{
  class ADDON
  {

    name = COMPONENT_NAME;
    author = "Dell, Zealot, Kurt, IndigoFox, Fank";
    authors[] = {"Dell", "Zealot", "Kurt", "IndigoFox", "Fank"};
    url = "https://github.com/OCAP2/OCAP";
    VERSION_CONFIG;
    requiredAddons[] = {"A3_Functions_F","cba_main","cba_xeh","ocap_main","ocap_extension"};
    units[] = {};
    weapons[] = {};
  };
};

class Extended_PreInit_EventHandlers {
  class ADDON {
    // This will be executed once in 3DEN, main menu and before briefing has started for every mission
    init = QUOTE( call COMPILE_FILE(XEH_preInit) );
  };
};

class Extended_PostInit_EventHandlers {
  class ADDON {
    // This will be executed once for each mission, once the mission has started
    init = QUOTE( call COMPILE_FILE(XEH_postInit) );
  };
};
