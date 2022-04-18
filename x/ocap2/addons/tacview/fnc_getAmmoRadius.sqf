#include "script_component.hpp"

params ["_ammoType", "_ammoSimType"];

_radius = GVAR(ammoRadiusCache) get _ammoType;
if (isNil "_radius") then {
  if (_ammoSimType == "ShotSmokeX") then {
    _radius = getNumber(configfile >> "CfgAmmo" >> _ammoType >> "explosionEffectsRadius");
  } else {
    _radius = getNumber(configfile >> "CfgAmmo" >> _ammoType >> "indirectHitRange");
  };
  GVAR(ammoRadiusCache) set [_ammoType, _radius];
};

_radius
