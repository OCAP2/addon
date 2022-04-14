/*
  Author: Karel Moricky

  Description:
  Generate a UTM Zone, Easting and Northing from lat and long fields. It uses NAD83 constants.
  Author: Based on VBScript by Andrew Pratt

  Parameter(s):
  _this select 0: NUMBER - longtitude (X)
  _this select 1: NUMBER - latitude (Y)
  _this select 2 (Optional): NUMBER - forced zone

  Returns:
  ARRAY - [easting,northing,zone]
*/
#include "script_component.hpp"

private ["_lat","_lon","_zone","GVAR(sin1)","_a","_b","_f","_rm","_n","_k0","_e1sq","_e","_e2","_a0","_b0","_c0","_d0","_e0","_o2","_p2","_q2","_r2","_s2","_t2","_v2","_x2","_y2","_z2","_aa2","_ab2","_ac2","_ad2","_northing","_easting","_zone"];

//--- Input
_lon = _this param [0,0,[0]];
_lat = _this param [1,0,[0]];
_zone = _this param [2,31 + floor(_lon / 6),[0]];

//--- Constants
if (isNil QGVAR(sin1)) then {
  EGVAR(convert,sin1) = pi / (180 * 3600);
  EGVAR(convert,a) = 6378137; // semimajor axis
  EGVAR(convert,b) = 6356752.314; // semiminor axis
  EGVAR(convert,f) = 0.003352811;
  EGVAR(convert,rm) = 6367435.68;
  EGVAR(convert,n) = (EGVAR(convert,a) - GVAR(b)) / (EGVAR(convert,a) + GVAR(b));
  EGVAR(convert,K0) = 0.9996;
  EGVAR(convert,e1sq) = 0.006739497;
  EGVAR(convert,e) = sqrt(1 - (EGVAR(convert,b) / EGVAR(convert,a))^2);
  EGVAR(convert,e2) = EGVAR(convert,e) * EGVAR(convert,e) / (1 - EGVAR(convert,e) * EGVAR(convert,e));
  EGVAR(convert,A0) = EGVAR(convert,a) * (1 - EGVAR(convert,n) + (5 * EGVAR(convert,n) * EGVAR(convert,n) / 4) * (1 - EGVAR(convert,n)) + (81 * EGVAR(convert,n)^4 / 64) * (1 - EGVAR(convert,n)));
  EGVAR(convert,B0) = (3 * EGVAR(convert,a) * EGVAR(convert,n) / 2) * (1 - EGVAR(convert,n) - (7 * EGVAR(convert,n) * EGVAR(convert,n) / 8) * (1 - EGVAR(convert,n)) + 55 * EGVAR(convert,n)^4 / 64);
  EGVAR(convert,C0) = (15 * EGVAR(convert,a) * EGVAR(convert,n) * EGVAR(convert,n) / 16) * (1 - EGVAR(convert,n) + (3 * EGVAR(convert,n) * EGVAR(convert,n) / 4) * (1 - EGVAR(convert,n)));
  EGVAR(convert,D0) = (35 * EGVAR(convert,a) * EGVAR(convert,n)^3 / 48) * (1 - EGVAR(convert,n) + 11 * EGVAR(convert,n) * EGVAR(convert,n) / 16);
  EGVAR(convert,E0) = (315 * EGVAR(convert,a) * EGVAR(convert,n)^4 / 51) * (1 - EGVAR(convert,n));
};

//--- Calculate
_O2 = (6 * _zone) - 183;
_P2 = (_lon - _O2) * 3600 / 10000;
_Q2 = _lat;// * pi / 180;
_R2 = _lon;// * pi / 180;
_S2 = EGVAR(convert,a) * (1 - EGVAR(convert,e) * EGVAR(convert,e)) / ((1 - (EGVAR(convert,e) * sin(_Q2))^2)^(3 / 2));
_T2 = EGVAR(convert,a) / ((1 - (EGVAR(convert,e) * sin(_Q2))^2)^(1 / 2));
_V2 = _A0 * (_Q2 * pi / 180) - EGVAR(convert,B0) * sin(2 * _Q2) + _C0 * sin(4 * _Q2) - EGVAR(convert,D0) * sin(6 * _Q2) + EGVAR(convert,E0) * sin(8 * _Q2);
_X2 = _V2 * EGVAR(convert,K0);
_Y2 = _T2 * sin(_Q2) * cos(_Q2) * EGVAR(convert,sin1)^2 * EGVAR(convert,K0) * (100000000) / 2;
_Z2 = ((EGVAR(convert,sin1)^4 * _T2 * sin(_Q2) * cos(_Q2)^3) / 24) * (5 - tan(_Q2)^2 + 9 * EGVAR(convert,e1sq) * cos(_Q2)^2 + 4 * EGVAR(convert,e1sq)^2 * cos(_Q2)^4) * EGVAR(convert,K0) * (10000000000000000);
_AA2 = _T2 * cos(_Q2) * EGVAR(convert,sin1) * EGVAR(convert,K0) * 10000;
_AB2 = (EGVAR(convert,sin1) * cos(_Q2))^3 * (_T2 / 6) * (1 - tan(_Q2)^2 + EGVAR(convert,e1sq) * cos(_Q2)^2) * _k0 * (1000000000000);
_AC2 = ((_P2 * EGVAR(convert,sin1))^6 * _T2 * sin(_Q2) * cos(_Q2)^5 / 720) * (61 - 58 * tan(_Q2)^2 + tan(_Q2)^4 + 270 * EGVAR(convert,e1sq) * cos(_Q2)^2 - 330 * EGVAR(convert,e1sq) * sin(_Q2)^2) * EGVAR(convert,K0) * (1E+24);
_AD2 = (_X2 + _Y2 * _P2 * _P2 + _Z2 * _P2^4);

//--- Result
_Northing = If (_AD2 < 0) then {
  10000000 + _AD2;
} else {
  _AD2;
};
_Easting = 500000 + (_AA2 * _P2 + _AB2 * _P2^3);
_Zone = _zone;

[_Easting,_Northing,_Zone]
