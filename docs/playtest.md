# Studio release gate (#9)

Status: **not played in Studio**. Luau compilation, offline logic tests and a
Rojo build are automated; they do not establish runtime, device or pacing results.
Use a separate, private published test experience and disposable test accounts.
Never enable Studio DataStore access against production saves for this pass.

## Reproducible automated checks

Install `luau`, `luau-compile`, and Rojo 7.6.1, then run from the repository root:

```sh
python3 scripts/check.py
rojo build default.project.json -o /tmp/grow-a-golem.rbxlx
```

CI builds Luau commit `32c28089305f488f901aaf1dbf3fd1cb65fa3d11` and checks both.
The regression runner executes the real Config, Stats, lease rules, Ascension
handlers and DataService load/save paths with minimal service/value shims. This is a syntax and logic check,
**not a Roblox type check** and not an emulator for the engine or platform APIs.

## Save safety decision

Keep the existing DataStore name and save shape. Add an atomic `_session` lease
inside each existing player record rather than migrate libraries and saves in
this change. Each load obtains a unique token using UpdateAsync; each save checks
that token inside the same UpdateAsync callback. Autosaves renew a 180-second
lease every 60 seconds; orderly leave/shutdown saves release it. Saves serialize
per profile and deep-copy their snapshot before yielding. A denied lease blocks
joining, including in Studio; API failure in Studio still permits unsaved testing.
A failed live load kicks rather than writing defaults. Lease loss disables saving
and disconnects the old session. Disconnected loads release any acquired lease.

ProfileStore remains a reasonable future replacement; adopting it is not required
for this atomic ownership check. It would require migration and lifecycle tests.
No session lease can make a two-player trade atomic across two DataStore keys,
so trades use their own escrow and journal (`src/shared/TradeJournal.luau`,
DataStore `TradeJournal_v1`): offered spares wait in escrow in both saves, one
journal write decides the trade, and each save settles from it, on its next
load if the server died. Once both sides' saves are written without the trade,
the journal record is removed (#68); a trade cut off mid-escrow may leave one
small record behind.

Before publishing, **drain old servers running the version without leases**.
Those binaries do not respect ownership tokens and can still overwrite records.
Do not roll back to that older version while leased servers are active.

Required published-place tests:

- [ ] Save progress, leave and rejoin; minerals, parts, artifacts, cosmetics and upgrades survive.
- [ ] Join two servers rapidly: the second refuses an active lease; after the first releases it, join succeeds.
- [ ] Interrupt a server without release; the save remains unchanged and becomes joinable after the lease expires.
- [ ] Force an expired lease takeover; the old server cannot save over the new server.
- [ ] Disconnect while load is pending, during a purchase save, and during shutdown. Rejoin without a wipe.
- [ ] Existing v1 saves reconcile all four new minerals and the Ascension fields.
- [ ] Studio API access disabled: visible unsaved warning, no live writes.
- [ ] Trade with two test accounts: both see "Saving your trade..." then "Trade complete", and both keep the swapped spares after rejoining.
- [ ] Shut the server down (or stop the test) straight after both press Confirm. On rejoin both players either have the swapped spares or both have their own back, never a mix; the Trade tab doesn't stay stuck on "still being saved".
- [ ] Existing saves with a pending-free `trades` table load and trade normally.

## Gameplay matrix

Record place version, date, device, player count, Output errors and reproduction
steps. Mark a row passed only after actually running it. Keep uncensored player
names and personal information out of public reports.

| Pass | Checks | Result |
| --- | --- | --- |
| Fresh solo | Tutorial; auto-combat/mining; all forge slots; every menu/button; boss 1 through boss 6; every travel gate | Not run |
| Input | PC WASD/Q/E/R, controller stick/X/Y/B, phone emulator joystick and buttons | Not run |
| Feedback | Dodge each slam; boss HP bar, artifacts, growth, level banner; authored part movement and skin preview | Not run |
| Three clients | Invite/accept/leave, share-range boundary, friend bonus, trading Ready/countdown/Confirm | Not run |
| Rewards | Offline cap; daily/week rollover; streak; quests; session gifts; codes; event track | Not run |
| Commerce | Unset IDs show Coming soon; test pass/product receipts once configured; restricted policy hides luck/trades | Not run |
| Tower | Set `Config.Tower.enabled = true`. Solo run on Mossy Quarry: waves 1 to 10, boss on 5 and 10, reward per wave matches the menu, golem returns home after. Three clients: leader starts, both others accept, all move in; a decline and a timeout each cancel; one player travels away mid-wave and stops being paid; everyone knocked out ends the run; four runs at once, the fifth is told it's full; Output clean throughout | Not run |
| Progression | Six zones; weighted tank/swarmer spawns; gold elite every 20 successful zone spawns; eight tiers; Awakening; Ascension reset and upgrades | Not run |
| Assets | Remove Assets folder to check fallback; malformed empty model falls back; imported art never collides; new WAV uploads audible with permissions | Not run |
| Persistence | Published-place checks above; leaderboards; fast hopping; leave/rejoin | Not run |
| Phone | Readable HUD/buttons; reduced frame rate; no errors at max player/enemy count | Not run |

## Timing sheet

Run at least three fresh, purchase-free saves. Stop the stopwatch while debugging.
Do not use developer grants, codes, parties or offline rewards in baseline runs;
record event modifiers and run a second pass with them enabled. Report median and
range. Targets below are hypotheses, not measured facts.

| Milestone | Target | Run 1 | Run 2 | Run 3 |
| --- | --- | --- | --- | --- |
| First mineral | <15 s | — | — | — |
| First forge | <2 min | — | — | — |
| First growth | <6 min | — | — | — |
| Old Rockjaw | 10–20 min | — | — | — |
| Zone 2 | <25 min | — | — | — |
| First Awakening | 2–4 h | — | — | — |
| Zone 4 | Set after baseline | — | — | — |
| Zone 5 | Set after zone 4 | — | — | — |
| Zone 6 | Set after zone 5 | — | — | — |
| All content | ≥20 h goal, unverified | — | — | — |

The six-zone configuration is provisional. Do not increase grind just to hit
20 hours. Adjust Config from measured kill, mining, travel and upgrade times.
With parent/guardian consent, observe 2–3 age-appropriate testers for 15 minutes
without hints; record where they stall, then retest the onboarding fixes.

Issue #9 stays open until the engine, persistence and timing results are filled in.
