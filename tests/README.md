# Recorder regression tests

`recorder_regressions.sqf` and `client_sampler_regressions.sqf` exercise the
installed addon's actual submission functions, sampling callbacks, export reset
and restart entry point. They require Arma multiplayer; HEMTT checks/builds do not
execute them.

Use a **disposable** CBA-only test mission with OCAP on the server only, auto-start
disabled, and two connected players with different network owners. Give one player
an assigned Zeus curator. Name the non-curator player `testClient` and the curator
player `testCurator` in the editor. Copy both scripts into the mission's `tests/`
folder and execute on the server:

```sqf
[testClient, testCurator] execVM "tests\recorder_regressions.sqf";
```

Run once on a dedicated server and once on a listen server with `testClient` as
the host. Allow `call` and the five tested submission endpoints in the test
mission's `CfgRemoteExec`; the synchronization barrier also uses `call`.

The RPT must end with `[OCAP regression] ALL TESTS PASSED`, with no script errors.
The suite checks that a real remote client cannot overwrite another player's
medical diff baseline, impersonate a curator, or submit Zeus reports without
curator assignment. Static-weapon assembly/disassembly spoofing must leave no
claim or dedupe state. Positive controls cover legitimate static-weapon owners,
direct server AI calls, snapshot ownership and curator submissions.

The client subtest uses the actual installed sampler callback from CBA's timed
PFH registry (`CBA_common_PFHhandles` / `CBA_common_perFrameHandlerArray`). It
switches control between identical-kit units, checks independent object and
entity-id changes, and verifies that all caches and radio readiness are reset.
With death snapshots disabled and the inventory interval still at 120 seconds,
each new id must immediately receive a full initial inventory on its next turn;
an unchanged unit must not resend early. The server checks the accepted snapshot
baselines and emitted full payloads. The client restores the original player and
sampler afterwards.

The same client subtest exercises the installed TFAR LR-code helper with mocked
TFAR APIs and an active `[radioObject, qualifier]` tuple. An empty live code with
codes enabled must query the object's `tf_encryptionCode` and resolve the side
variable. It checks the complete tuple reaches the live-code API, only the object
reaches the property API, and empty side codes, non-empty live codes and globally
disabled codes remain safe. TFAR is not required; mocks are restored afterwards.

The suite also samples 100 successive fuel/damage improvements of `0.005`,
checks idle closure and whole-session noise suppression, then exports and restarts
with different static membership and reused vehicle ids. Pending disassembly
claims, dedupe state and an assembly callback from the old recording must not
produce events in the new one.

Extension writes are intercepted, and the servicing clock is advanced only in an
unscheduled block. The suite replaces recording state and removes the servicing
PFH; restart the mission afterwards. It is an opt-in test artifact, not included
in the release PBOs.

`save_limits_regressions.sqf` checks the save limits: a recording registers the
mission with the extension once, when it starts, and begins the capture and
announces it only once the extension confirms it, however long that takes; a
failed start ends the recording; a mission that ends while it registers is
discarded; a mission that ends before `minMissionTime` is discarded
(`:MISSION:DISCARD:`) unless a mission script exports it on the same frame; a
longer one is saved; `saveMissionEnded` disabled does neither. It needs no
players and takes about a minute. Execute it on the server once the extension
storage is initialized, with auto-start disabled:

```sqf
execVM "tests\save_limits_regressions.sqf";
```

The RPT must end with `[OCAP save limits] ALL TESTS PASSED`.

Lifecycle commands to the extension are intercepted, so nothing is registered
or saved. The suite replaces recording state and resets per-unit recording
variables, and a recording start it simulates also satisfies the auto-start
waiter; restart the mission afterwards. It is an opt-in test artifact, not
included in the release PBOs.
