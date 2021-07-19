params ["_entity", ["_respawn", false]];

if ((_entity call BIS_fnc_objectType) # 0 == "Soldier") then {
	_entity addEventHandler ["FiredMan", { _this spawn ocap_fnc_eh_fired; }];
};
_entity addMPEventHandler ["MPHit", { _this spawn ocap_fnc_eh_hit; }];

if (!_respawn && (_entity call BIS_fnc_objectType) # 0 == "Soldier") then {
	ocap_fnc_trackAceThrowing remoteExec ["call", _entity];
};
