# Automatic recording lifecycle

After `saveOnEmpty` exports a recording, the recorder checks the player threshold
every 10 seconds. It starts a new recording only if `autoStart` was enabled at
mission initialization and `autoRestartAfterEmpty` is enabled. Manual starts and
paused recordings keep their existing behavior.

`excludeHeadlessClientsFromAutoStart` still controls the player count for both
initial start and restart. Disabling it allows headless clients alone to meet the
threshold, even after an empty-server save.

The existing `OCAP_settings_bufferPlayerConnectionEvents` setting now controls
**Include Connected Players at Recording Start**. When enabled, a new recording
includes one `connected` event per currently connected human player at internal
frame 1 (the first recorded frame). Disconnected players and headless clients are
omitted. No connection history is stored while waiting for a recording, so churn
between recordings cannot accumulate or appear in a later recording. Active and
paused recordings still receive live connection events. The Steam ID setting and
`playerUid` payload format are unchanged.

## Dedicated-server verification

These scenarios require Arma 3 and the recorder extension; HEMTT checks and builds
do not exercise the server lifecycle. Inspect the resulting recordings as well
as the server notifications.

1. Enable auto-start, restart and save-on-empty. Reach the player threshold,
   record beyond `minMissionTime`, then disconnect everyone. Verify one export;
   rejoin below the threshold and verify recording stays stopped; reach the
   threshold and verify a fresh recording starts within 10 seconds. Repeat.
2. Disable auto-start before mission initialization, then start manually. Repeat
   the empty-server save and rejoin flow. Verify no automatic recording starts,
   even when the threshold is reached. Verify manual start still works.
3. Between recordings, connect and disconnect several players. Leave some humans
   and a headless client connected, then start. Verify only the humans still
   connected have startup `connected` events, at the first frame; no stale
   `disconnected` events appear. Repeat before the first recording.
4. Disable the startup-player setting and verify no startup snapshot is emitted.
   Check live connect/disconnect events while recording and paused. With Steam
   IDs enabled, verify `playerUid`; disable the setting and verify it is omitted.
5. With headless-client exclusion enabled, verify headless clients do not help
   reach the start/restart threshold. With it disabled, verify the configured
   counting behavior, including the documented headless-only restart case.
