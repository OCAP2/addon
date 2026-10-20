/* ----------------------------------------------------------------------------
FILE: fnc_getConfigDisplayName.sqf

FUNCTION: OCAP_recorder_fnc_getConfigDisplayName

Description:
  The display name of a config class, safe to store in a recording, or "" when
  the config holds no name that is.

  Never store a localized string in a recording: getText resolves a stringtable
  reference in the *recording server's* language, and the file is read in eight.
  getTextRaw returns what the config actually holds:

    - a literal, the text the mod author typed, which is returned as-is.
    - a "$STR_..." reference, which SQF can only read in the game's language.
      "" is returned and the caller falls back to something English, usually
      the class name.
    - an __EVAL(...) expression, stored unevaluated: getTextRaw hands back its
      source, `format ["%1 [BLUE]", getText (...)]`, and only getText runs it.
      The evaluated name is returned, or "" if it came out non-ASCII, which
      means the expression pulled in a localized name.

  The non-ASCII test is a heuristic, and only expressions go through it:

    - a localized name in a Latin-script language with no diacritics on that
      server ("Gewehr [BLUE]" on a German one) is plain ASCII and gets recorded.
      SQF cannot tell it from English. Cyrillic, Czech, Polish and the like are
      caught.
    - an English name with a typographic character ("7.62×51mm", "–") is
      rejected, and the caller falls back to its class name.

  Clients have none of our functions, so <OCAP_recorder_fnc_installPlayerTrackingClients>
  ships this one to them as OCAP_recorder_client_getConfigDisplayName.

Parameters:
  _config - The class whose displayName to read [Config]

Returns:
  The display name, or "" [String]

Examples:
  > private _name = [configOf _vehicle] call FUNC(getConfigDisplayName);
  > if (_name isEqualTo "") then {_name = typeOf _vehicle};

Public:
  No

Author:
  Smith
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params [["_config", configNull, [configNull]]];

private _entry = _config >> "displayName";
private _name = getTextRaw _entry;

// For a literal getText agrees with getTextRaw; only an expression differs.
if (_name isEqualType "" && {_name isNotEqualTo ""} && {(_name select [0, 1]) isNotEqualTo "$"}) then {
  private _evaluated = getText _entry;
  if (_evaluated isNotEqualTo _name) then {
    _name = ["", _evaluated] select (((toArray _evaluated) findIf {_x > 127}) == -1);
  };
};

// getTextRaw hands back an array for a config entry written as one.
if (_name isEqualType []) then {_name = _name param [0, ""]};
if (!(_name isEqualType "")) exitWith {""};
_name = trim _name;
if ((_name select [0, 1]) isEqualTo "$") exitWith {""};
_name
