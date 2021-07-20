params ["_victim", ["_killer", objNull], ["_instigator", objNull]];

if (isNull _instigator) then {
	_instigator = UAVControl vehicle _killer select 0;
};
if ((isNull _instigator) || (_instigator == _victim)) then {
	_instigator = _killer;
};
if (_instigator isKindOf "AllVehicles") then {
	_instigator = call {
		if(alive(gunner _instigator))exitWith{gunner _instigator};
		if(alive(commander _instigator))exitWith{commander _instigator};
		if(alive(driver _instigator))exitWith{driver _instigator};
		effectiveCommander _instigator
	};
};
if (isNull _instigator) then {
	_instigator = _killer;
};

_instigator;
