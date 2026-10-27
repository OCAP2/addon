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

## Save limits and storage

`minPlayerCount` and `minMissionTime` are enforced by the addon, so they must
hold for every storage, including the `websocket` storage that streams a
recording to the web server while it records:

- The mission registers with the extension (`:MISSION:START:`) only when a
  recording starts, not at mission load. A mission that never reaches the
  auto-start conditions, such as `minPlayerCount`, leaves nothing in storage.
  The web server previously listed such missions as empty `partial`
  recordings.
- The capture, and with it the "Recording started." and "Mission has started!"
  events, begins once the extension answers `:MISSION:OK:`. The addon waits
  for that answer, or `:MISSION:FAILED:`, however long the extension takes, for
  example while it still saves the previous recording. Further start requests
  meanwhile register nothing more, but undo a pause and tell players recording
  starts once the mission is registered; after 30 seconds it notifies players
  that it is still waiting. A start request while the capture runs only
  reports that OCAP is already recording. Each registration carries a token
  the extension echoes, so a late answer to an earlier mission's registration
  is ignored. Without a running extension (no `:SYS:VERSION:` after 60
  seconds) the recording gives up. A pause meanwhile (`OCAP_pause`) holds the
  capture back until recording resumes; a pause while storage still
  initializes does not register the mission at all until then. If the mission
  ends first, the registered mission is discarded instead, whatever
  `saveMissionEnded` says. If the mission unloads before the extension
  answers, the extension refuses that start, or, if the start already reached
  its storage, drops the empty mission when the next one loads (a web server
  older than protocol 3 saves it as an empty `partial` instead). A start
  request a minute after an unanswered `:MISSION:START:` sends it again.
  Storage that is still initializing is waited for too, until the extension
  reports `:STORAGE:ERROR:`; players are notified after 60 seconds.
- A pause before the capture began only holds it back: players were not told
  recording started, so they are not told it stopped. Auto-start leaves such a
  pause alone; the next start request lifts it.
- `OCAP_recorder_recording` is true from the start request on, while
  `OCAP_recorder_startTime` is set once the capture runs, and the server-local
  CBA event `OCAP_recordingStarted` fires then. A mission script that starts
  recording (`OCAP_record`) and records its own events or exports right away
  should wait for that event. Before this change a start recorded at once when
  the mission had registered at load.
- When the mission ends (`MPEnded` with `saveMissionEnded`) before the
  recording reached `minMissionTime`, the recording is discarded with
  `:MISSION:DISCARD:`, one frame later, so a mission script can still save it
  through `OCAP_exportData` on the server in the same frame (before `MPEnded`,
  or from its own `MPEnded` handler without suspending). A later export, for
  example one a client raises, finds the recording already discarded. The `memory` storage drops it, the `websocket`
  storage tells the web server to drop it (web protocol version 3; an older web
  server still saves it as `partial`). A recording that reached
  `minMissionTime` is saved as before.

This needs an extension with `:MISSION:DISCARD:`, `:MISSION:FAILED:` and
`:STORAGE:ERROR:` (OCAP2/extension#217). An older one rejects the discard,
which the server RPT logs as a warning, and never answers a failed start or a
failed storage, so such a recording keeps waiting.

When an admin changes the mission (`#missions`, `#restart`), the addon gets no
event: the extension ends the recording when the next mission loads. Each
registration asks it to drop the recording then (`:MISSION:START:` with
`discard`) until the recording reaches `minMissionTime`; from that frame the
capture loop sends `:MISSION:KEEP:`, and such a recording is saved by the web
server as `partial`, as before. This holds for the `websocket` storage, with a
web server at protocol 3; an older extension ignores the request, and logs the
unknown `:MISSION:KEEP:` once per recording.

A recording ended otherwise without a save or a discard is still saved by the
web server as `partial`, whatever its length: after a crash, after a server
shut down with `#shutdown` or from the mission list, and one that captured
anything when the mission ends with `saveMissionEnded` disabled.

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
6. With the `websocket` storage, load a mission and stay below `minPlayerCount`.
   Verify the web server shows no recording, live or saved, until the threshold
   is reached, and that the extension log has no `WebSocket mission started`
   before then.
7. With the `websocket` storage, record and end the mission (`endMission`)
   before `minMissionTime`. Verify the "was not saved" notification, a
   `Discarded recording dropped by storage` line in the server RPT and that the
   web server keeps no recording of it. End a mission past `minMissionTime` and
   verify it is saved as before. Repeat with the `memory` storage and verify no
   file is written for the short mission. The discard is sent one frame after
   `MPEnded`, so this also checks that the server still runs that frame.
8. With auto-start, verify the saved recording holds the "Recording started."
   and "Mission has started!" events at its start.
9. With the `websocket` storage, record less than `minMissionTime`, then change
   the mission with `#missions` and load another one (or `#restart`). Verify
   the extension log has `abandoned before it met the addon's save limits;
   discarding it` and the web server keeps no recording of it. Record past
   `minMissionTime` (the extension log has `Received :MISSION:KEEP:`), change
   the mission again and verify it is saved as `partial`.
