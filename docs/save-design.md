# Save design: keep our own session leases, not ProfileStore (R5.5)

Decided 2026-10-27. Sources accessed 2026-10.

**Decision: keep `DataService` and its session leases for launch. Don't move to ProfileStore now.** Revisit if one of the triggers at the end happens.

## What we have

- **Session leases** (`DataService`, `src/shared/SessionLease.luau`): each load takes a lease token inside the same `UpdateAsync` that reads the save, and each save checks that token inside its own `UpdateAsync`. Leases last 180 seconds, are renewed by the 60-second autosave and are released on leave and shutdown. A save that lost its lease is refused and the player is kicked, a failed live load kicks instead of playing on blank data, and saves for one player never overlap. Offline tests cover these paths (`tests/data-service.luau`).
- **Purchases** (`PassService`): a receipt is only granted once the save holding it is written; otherwise it returns `NotProcessedYet` so Roblox retries.
- **Trades** (R5.2, PR #32): escrow in both saves and one journal record that decides each trade, so a crash can't copy or lose an artifact.

This is the same design as Roblox's own guide to player data and purchases: a lock written into the key in the same atomic `UpdateAsync` as the read, an expiry the owning server keeps refreshing, release on the final save, and receipts recorded in the save before they're granted ([Roblox: player data and purchasing](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing)).

## What ProfileStore is

ProfileStore is loleris's free successor to ProfileService, released October 2024. It is distributed as a single ModuleScript on the Creator Store; there's no official Wally package ([DevForum: ProfileStore](https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543/)). From its announcement:

- It session-locks each profile like ProfileService, but uses MessagingService to ask the server holding a lock to save and hand it over. So a new server takes ownership smoothly instead of failing the request, and autosaves can run less often (every 300 seconds by default).
- `MessageAsync` sends messages to a profile whether or not it's loaded, which suits gifting. It replaces ProfileService's GlobalUpdates.
- Its locking is per profile. It isn't meant for global state, and it says nothing about changing two profiles atomically. A trade would still need its own escrow and journal.
- Data is shaped by a template, and `Reconcile` fills in missing fields, which is what our `reconcile` already does.

The post doesn't say how existing raw DataStore records would be imported, or what license the code carries (unverified either way).

## Comparison

| | Our leases | ProfileStore |
| --- | --- | --- |
| Stops two servers writing one save | Yes, token checked in every `UpdateAsync` | Yes |
| Fast server hop while the old server still holds the lock | Kicks with "still saving in another server, rejoin shortly"; succeeds once the old server releases (usually at once on leave) | Asks the old server to hand over through MessagingService, without a kick |
| Server crash | New server waits up to 180 s for the lease to expire | Not described in the announcement; a crashed server can't answer a handover request, so presumably it also waits for the lock to go stale (inference) |
| Atomic trade between two players | Escrow and journal (#32) | Not provided; same escrow and journal needed |
| Cross-server messages and gifting | None (not needed today) | `MessageAsync` |
| Tested offline in CI | Yes, real code against mocks | Would need new mocks for MessagingService and its internals |
| Moving existing saves | Nothing to move | Needs a migration path and new lifecycle tests (format unverified) |

## Why we keep ours

1. It already does the one thing that matters most, refusing stale writes, and it follows Roblox's documented pattern.
2. ProfileStore wouldn't make trades safe; the escrow and journal are needed either way.
3. Switching now means migrating saves that have never been tested in a published place. That's more risk before the first playtest, not less.
4. The main thing ProfileStore adds, a smooth handover on fast hops, matters most for games that teleport between places. Grow A Golem is one place.

## When to revisit

Reopen this decision (file an issue) if any of these happen:

- Playtests or analytics show players often kicked with "still saving in another server" on normal rejoins.
- The game adds teleports between places.
- The game adds gifting or any feature that needs messages to offline or remote players.
- A save-loss bug traces back to the lease code itself.

If it's reopened, the switch needs a written migration plan (reading old `PlayerData_v1` records into profiles, then a rollback plan) and the published-place save tests in `docs/playtest.md` rerun before release.

## Sources

- Roblox Creator Docs, Implement player data and purchasing systems: https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing (accessed 2026-10)
- Roblox DevForum, ProfileStore announcement by loleris, 2024-10-11: https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543/ (accessed 2026-10)

## Kingdom campaign foundation (#213)

`campaign` has an independent schema version (currently 1), string-keyed region access,
learned abilities, discoveries, completed obstacles, sanctuary projects and titan milestones.
New profiles have quarry access and otherwise empty records. Reconciliation fills missing
fields; the one-time migration evaluates the unchanged legacy boss/size gates and eligible
current part tiers. It grants no rewards and invents no obstacle, project or hunt history.
Existing inventory, receipts and artifact bags keep their values.

Migration runs after successful lease acquisition and reconciliation, before gameplay starts,
even with `Config.Kingdom.enabled = false`. The same profile save/lease lifecycle persists it;
failed live loads still kick without creating a writable blank profile. Snapshots explicitly
project the six campaign state maps, omitting the schema version and future server bookkeeping.
Both prestige handlers retain the campaign while resetting their existing run fields.

`Stats.zoneUnlocked` remains the current-run boss/size check for Core caps and return mining;
`Stats.campaignZoneUnlocked` checks earned access. `Stats.travelUnlocked` selects the latter
only when kingdom rollout is enabled. Ascension still requires a fresh current-run boss win.
The rollout flag stays off pending #219/#228; toggling it off preserves campaign data and
restores legacy travel. Rollback here means disabling the flag in a campaign-aware build.
Published save/rejoin validation remains part of those integration stories.
