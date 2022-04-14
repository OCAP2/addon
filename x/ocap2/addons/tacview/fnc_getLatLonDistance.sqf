#include "script_component.hpp"

params ["_lat1", "_lon1", "_lat2", "_lon2"];

// "debug_console" callExtension str("param = " + str(_this));
_params = _this apply {deg _x};
// "debug_console" callExtension str("params = " + str(_params));

_R = 6371; // Radius of the earth in km
_dLat = _lat2 - _lat1;
_dLon = _lon2 - _lon1;
_a =
  sin(_dLat/2) * sin(_dLat/2) +
  cos(_lat1) * cos(_lat2) *
  sin(_dLon/2) * sin(_dLon/2)
  ;
_c = 2 * ((sqrt _a) atan2 (sqrt (1-_a)));
_km = _R * _c; // Distance in km
_km
