# Non-Bullet Projectile Server-Side Lifecycle

## Problem

Non-bullet projectiles (grenades, smoke, rockets, flares) go missing in recordings on dedicated servers. The client-side `Deleted` EH doesn't fire reliably for long-lived projectiles due to locality transfer or engine cleanup. PR #88 added a PFH failsafe, but the root cause remains: the client is the sole source of truth for data that may never reach the server.

Bullets (LMGs, rifles) are unaffected — they're short-lived and the `Deleted` EH fires reliably.

## Decision: Split by simulation type

- `shotBullet` → **unchanged**, fully client-side
- Everything else → **server-side lifecycle** (server accumulates data, sends to extension)
- Placed objects (`weapon == "put"`) → **unchanged** (separate lifecycle, fixed in PR #88)

## Architecture

### Data Flow (non-bullet projectile)

```
CLIENT (projectile owner)                          SERVER
─────────────────────────                          ──────
1. FiredMan EH fires
   → fnc_eh_fired_client creates data array
   → sim != "shotBullet" detected
   → Generates client temp ID (clientOwner + counter)
   → Sends [tempId, fullDataArray] ─────────────► 2. OCAP_handleProjectileInit
     via CBA_fnc_serverEvent                         → Assigns OCAP ID (GVAR(nextId))
                                                     → Stores in GVAR(trackedProjectiles)
                                                       key: "clientOwner:tempId"
                                                       value: data array + creationTime

3. PFH (every frameCaptureDelay)
   → [tempId, [tickTime, frame, "x,y,z"]] ─────► 4. OCAP_handleProjectilePos
     via CBA_fnc_serverEvent                         → Appends to (data select 14)

5. HitPart/HitExplosion/Deflected fires
   → [tempId, hitData...] ──────────────────────► 6. OCAP_handleProjectileHit
     via CBA_fnc_serverEvent                         → Appends to (data select 16)
                                                     → Appends pos to (data select 14)

7. Deleted EH (or PFH isNull failsafe)
   → [tempId, finalPos] ───────────────────────► 8. OCAP_handleProjectileDone
     via CBA_fnc_serverEvent                         → Appends final pos
                                                     → Sends EVENT:PROJECTILE to extension
                                                     → Removes from hashmap

                                                  9. Timeout PFH (every 30s)
                                                     → Entries older than 120s:
                                                       send data, remove from hashmap
```

### Client Temp ID

The client generates a temp ID for correlation: `clientOwner * 100000 + localCounter`. The server maps `"clientOwner:tempId"` to avoid collisions between clients. The OCAP ID (`GVAR(nextId)`) is assigned server-side and only used in the final `EVENT:PROJECTILE` data — the client never needs to know it.

### Extension Protocol

No changes. The server assembles the same 20-element `EVENT:PROJECTILE` array and sends it via `handleFiredManData` → `EFUNC(extension,sendData)`.

## File Changes

### New: `fnc_eh_fired_clientProjectile.sqf`

Non-bullet projectile EH setup on the client. Receives `[_projectile, _tempId]`.

- HitExplosion, HitPart, Deflected, Explode EHs: send hit data to server via `OCAP_handleProjectileHit` with `_tempId`
- Deleted EH: sends `OCAP_handleProjectileDone` with `_tempId` + final position
- PFH: sends `OCAP_handleProjectilePos` each tick; on `isNull`, sends `OCAP_handleProjectileDone` as failsafe

No local data accumulation. All data goes to the server immediately.

### Modified: `fnc_eh_fired_client.sqf`

After creating the data array:
- If `weapon == "put"` → placed object path (unchanged)
- If `sim == "shotSubmunitions"` → add SubmunitionCreated EH (children route based on their sim type)
- If `sim == "shotBullet"` → call `fnc_eh_fired_clientBullet` (unchanged)
- Else → generate temp ID, send to server, call `fnc_eh_fired_clientProjectile`

### Modified: `fnc_eh_fired_clientBullet.sqf`

Remove the PFH failsafe and sent flag (index 20) — these were added in PR #88 for non-bullets, which now go through the new file. This file returns to bullets-only: EHs write to local data, Deleted sends everything.

### Modified: `fnc_eh_fired_server.sqf`

Add four new CBA event handlers:
- `OCAP_handleProjectileInit` — store data in `GVAR(trackedProjectiles)` hashmap
- `OCAP_handleProjectilePos` — append position to stored data
- `OCAP_handleProjectileHit` — append hit + position to stored data
- `OCAP_handleProjectileDone` — send `EVENT:PROJECTILE` to extension, cleanup

Add timeout PFH (every 30s): iterate `GVAR(trackedProjectiles)`, send and remove entries older than 120s.

Distribute `FUNC(eh_fired_clientProjectile)` to clients via `remoteExec` (same pattern as existing functions).

### Config: `CfgFunctions`

Register `fnc_eh_fired_clientProjectile`.

## Submunitions

Parent projectile (`shotSubmunitions`):
- Skipped for tracking (no trajectory/hits to record)
- Only has `SubmunitionCreated` EH

Child submunitions:
- If child sim is `shotBullet` → client-side path (`fnc_eh_fired_clientBullet`)
- If child sim is anything else → server-side path (`fnc_eh_fired_clientProjectile`)

This matches current behavior where the parent is skipped.

## PR #88 Cleanup

- PFH failsafe and sent flag in `fnc_eh_fired_clientBullet.sqf` → removed (non-bullets use new file)
- Placed object Local EH in `fnc_eh_fired_server.sqf` → kept (unrelated, still needed)
