# Player Detail Tracking

OCAP can record a player's gear, medical state, stamina and radios as extra events
on the existing timeline. The playback card on the web UI reads those events; it
never fetches per-player data itself.

## Why the sampler runs on the client

The OCAP PBO and `callExtension` exist only on the **server**. For a remote unit,
`magazinesAmmoFull`, ACE/KAT `getVariable`s, `getStamina` and every `TFAR_fnc_*` /
`acre_api_fnc_*` call return empty, stale or default values.

The server therefore ships the sampler as a code block
(`fnc_installPlayerTrackingClients.sqf`) with a JIP id. Each client samples its
own local unit and sends the payload back with
`remoteExecCall [OCAP_recorder_fnc_submitPlayerSnapshot, 2]`. The server stamps
`unitId` and `playerUid` itself and is the only machine that talks to the
extension.

AI units are not sampled. The web profile still opens for them, but the Gear /
Medical / Stamina / Radios tabs stay hidden unless a snapshot of that kind exists.

## Settings

All of these live under **Options → Addon Options → OCAP - Recorder → Player Detail Tracking**.
They are server settings (`force` in `cba_settings.sqf`) and are publicVariabled
to clients after init.

| Setting | Variable | Default | Notes |
|---|---|---|---|
| Track Player Inventories | `OCAP_settings_trackPlayerInventory` | true | Containers, weapons, magazines, assigned items, load |
| Inventory Snapshot Interval | `OCAP_settings_playerInventoryInterval` | 120 s | Also writes immediately when the kit changes. Range 10–1800 |
| Snapshot Inventory on Death | `OCAP_settings_trackPlayerInventoryOnDeath` | true | Inventory + medical after the weapon-drop tick |
| Track Player Medical State | `OCAP_settings_trackPlayerMedical` | true | Vanilla hit points; ACE and KAT when loaded |
| Medical Snapshot Interval | `OCAP_settings_playerMedicalInterval` | 60 s | While healthy. Range 5–300 |
| Critical Medical Snapshot Interval | `OCAP_settings_playerMedicalCriticalInterval` | 10 s | ACE unconscious / cardiac arrest. Range 1–120. A wake-up also writes on the next PFH. |
| Track Player Stamina | `OCAP_settings_trackPlayerStamina` | true | Vanilla pool + ACE Advanced Fatigue when present. Also writes when carried load/mass changes. |
| Stamina Snapshot Interval | `OCAP_settings_playerStaminaInterval` | 30 s | Range 5–300 |
| Track Player Radio Settings | `OCAP_settings_trackPlayerRadio` | true | TFAR and/or ACRE2. Every carried TFAR SW is probed; nothing is written until the unit has actually carried a radio |
| Radio Snapshot Interval | `OCAP_settings_playerRadioInterval` | 120 s | Also writes on frequency / channel / carried-SW change. Range 10–1800 |
| Store Player Snapshots as Diffs | `OCAP_settings_trackPlayerSnapshotDiffs` | true | Unchanged snapshots are dropped; arrays are patched entry by entry; a full keyframe every 20 diffs |
| Fallback TFAR SW Range | `OCAP_settings_radioShortRangeMeters` | 5000 | Used only when the radio has no `tf_range`. Range 100–20 000 |
| Fallback TFAR LR Range | `OCAP_settings_radioLongRangeMeters` | 20000 | Same, for long-range radios. Range 1 000–100 000 |

Pinned production values:

```sqf
force OCAP_settings_trackPlayerInventory = true;
force OCAP_settings_playerInventoryInterval = 120;
force OCAP_settings_trackPlayerInventoryOnDeath = true;
force OCAP_settings_trackPlayerMedical = true;
force OCAP_settings_playerMedicalInterval = 60;
force OCAP_settings_playerMedicalCriticalInterval = 10;
force OCAP_settings_trackPlayerStamina = true;
force OCAP_settings_playerStaminaInterval = 30;
force OCAP_settings_trackPlayerRadio = true;
force OCAP_settings_playerRadioInterval = 120;
force OCAP_settings_trackPlayerSnapshotDiffs = true;
force OCAP_settings_radioShortRangeMeters = 5000;
force OCAP_settings_radioLongRangeMeters = 20000;
force OCAP_settings_trackServerFps = true;
force OCAP_settings_trackWeather = true;
```

If a deployment restricts `CfgRemoteExec`, whitelist
`OCAP_recorder_fnc_submitPlayerSnapshot` for clients → server or the snapshots
never arrive.

## What a gear entry carries

An item on the wire is its class, its count, and — for the lists the profile card
groups, meaning container cargo and magazines — a `cat` of `magazines`,
`grenades` or `medical`. `items` is the default and is left off.

Two things it deliberately does **not** carry:

- **The icon path.** The web UI used to guess an item's category by
  substring-matching the `.paa` path, which cost about 3 MB per recording for a
  path no browser can load. The recorder resolves the category from config
  instead: ACE's `ACE_isMedicalItem` (which ACE also sets on the vanilla
  `FirstAidKit` and `Medikit`, and which KAM sets on its own items), the
  magazines listed under the engine's `Throw` muzzles, and `CfgMagazines`
  membership. That is the same source ACE's own arsenal uses.
An item also carries its **display name**, but read with `getTextRaw` rather than
`getText`. `getText` resolves a stringtable reference in the *recording server's*
language, so a Czech server froze "Mapa" and "Obvaz (Elastický)" into recordings
shown to viewers in eight locales. `getTextRaw` returns what the config actually
holds:

- a **literal** — the text the mod author typed, which is English — and that is
  what gets recorded. On a real mission take this covers about 95% of classes:
  "5.56mm 30rnd Tracer Mag", "40mm HE Grenade Round (L123)", "Bergen MTP
  Rifleman H (B) [BAF]".
- a **`$STR_...` reference** — which SQF cannot read in any language but the one
  the game is running, and there is no way to ask for English. The name is built
  from the class instead, which is English by construction: `ACE_elasticBandage`
  becomes "Elastic Bandage" and `ItemMap` becomes "Map". This is what happens for
  vanilla and ACE items.

Either way the recording holds an English name for every item, including the two
medical labels the recorder resolves itself (IV bags and medications). The web UI
only derives a name when a recording does not carry one at all.

Recordings made before this change are converted by
`python/convert_recording_gear.py`, which translates a recorded name into English
through the mods' own stringtables and keeps it exactly as recorded when they have
no English for it.

## Snapshot diffs

A follow-up snapshot carries only what changed. Nested HashMaps are walked, and
an array whose entries have a unique `class`, `slot` or `part` is patched entry
by entry:

```json
{"diffOf": 40, "unitId": 7, "set": {
  "magazines": {"$key": "class",
                "put": [{"class": "UK3CB_BAF_556_30Rnd", "totalRounds": 269}],
                "del": ["Chemlight_green"]}}}
```

`put` upserts (merging onto the entry already there), `del` removes, and `ord`
appears only when put and del alone would leave the entries out of order —
`assignedItems` is read positionally by the Arsenal export, so its order is data.
Arrays with no unique identifier are still replaced whole.

Before this, one round leaving a magazine rewrote the player's entire magazine
list; it was the single largest cost in a recording.

## Medical layering

Vitals are written vanilla → ACE → KAT. ACE replaces the vanilla hit-point list
in the UI. When KAT is loaded, ACE's `spo2` is not written at all (it sits at
the default 97 and would drown KAT's pulse-ox reading).

Body treatments (wounds, bandages, IVs, tourniquets, airway items, …) are
generic `{kind, name, count, detail}` items on each body part so a new treatment
does not need a UI change.

## Radio range

Every carried TFAR SW from `TFAR_fnc_radiosList` is recorded (the selected one
flagged `active`), plus the active LR. TFAR range is `tf_range` from the radio
(walking `tf_parent` when needed) times the mission sending-distance
multiplicator. ACRE range is `70.71 * sqrt(power_mW)` from the live TX power.
The two fallback sliders are last-resort only.

On the first capture frame the server also writes `tfarSettings` and
`acreSettings` events with the live CBA values that change coverage.
TFAR stamps `TFAR_terrain_interception_coefficient` (default 7) and
`TFAR_globalRadioRangeCoef` (default 1). ACRE stamps
`acre_sys_core_terrainLoss` (0–1, default 1) and
`acre_sys_signal_signalModel` (default 2 = LOS Multipath). If a mod is
not loaded on the server those defaults are stamped anyway. Approximate
range for an ACRE radio uses ACRE's terrain-loss model, not TFAR's
coefficient. **Simple range** is still the recorded `rangeMeters` circle.

ACE blood pressure is stored `[diastolic, systolic]` and shown as `120/80`.

## Playback

Left panel → Units → click a player row. The card is frame-scoped: it shows the
latest snapshot at or before the playhead. Diffs are rebuilt before display.
Recordings that never wrote these events still play; the extra tabs simply do
not appear.
