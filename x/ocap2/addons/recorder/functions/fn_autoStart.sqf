/* ----------------------------------------------------------------------------
Script: ocap_fnc_autoStart

Description:
    Run during preInit to check for auto or manual start. Calls ocap_fnc_init.

Parameters:
    None

Returns:
    Nothing

Examples:
    call ocap_fnc_autoStart;

Public:
    Yes

Author:
    TyroneMF
---------------------------------------------------------------------------- */

#include "\userconfig\ocap\config.hpp"

if (ocap_autoStart) then {
    [] call ocap_fnc_init;
};
