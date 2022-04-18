
params ["_vehicle"];
(_vehicle call BIS_fnc_objectType) params ["_category", "_type"];

switch (_type) do {
  case "Car": { "Ground+Vehicle" };
  case "Helicopter": { "Air+Rotorcraft" };
  case "Motorcycle": { "Ground+Vehicle" };
  case "Plane": { "Air+FixedWing" };
  case "Ship": { "Sea+Watercraft" };
  case "StaticWeapon": { "Weapon+Static" };
  case "Submarine": { "Watercraft+Submarine" };
  case "TrackedAPC": { "Ground+Medium+Armor+Vehicle" };
  case "Tank": { "Ground+Heavy+Armor+Vehicle+Tank" };
  case "WheeledAPC": { "Ground+Light+Armor+Vehicle" };
  default { "Building" }; // Buildings are drawn with tiny little markers, so not a bad choice for unknown types of vehicle
};
