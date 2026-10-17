# Recorder regression tests

`recorder_regressions.sqf` exercises the installed addon's actual submission
functions, sampling callbacks, export reset and restart entry point. It requires
Arma multiplayer; HEMTT checks/builds do not execute it.

Use a **disposable** CBA-only test mission with OCAP on the server only, auto-start
disabled, and two connected players with different network owners. Give one player
an assigned Zeus curator. Name the non-curator player `testClient` and the curator
player `testCurator` in the editor. Copy this script into the mission's `tests/`
folder and execute on the server:

```sqf
[testClient, testCurator] execVM "tests\recorder_regressions.sqf";
```

Run once on a dedicated server and once on a listen server with `testClient` as
the host. Allow `call` and the four tested submission endpoints in the test
mission's `CfgRemoteExec`; the synchronization barrier also uses `call`.

The RPT must end with `[OCAP regression] ALL TESTS PASSED`, with no script errors.
The suite checks that a real remote client cannot overwrite another player's
medical diff baseline, impersonate a curator, or submit Zeus reports without
curator assignment. Positive controls check legitimate ownership and curator
submissions. It also samples 100 successive fuel/damage improvements of `0.005`,
checks idle closure and whole-session noise suppression, then exports and restarts
with different static membership and reused vehicle ids. Pending disassembly
claims, dedupe state and an assembly callback from the old recording must not
produce events in the new one.

Extension writes are intercepted, and the servicing clock is advanced only in an
unscheduled block. The suite replaces recording state and removes the servicing
PFH; restart the mission afterwards. It is an opt-in test artifact, not included
in the release PBOs.
