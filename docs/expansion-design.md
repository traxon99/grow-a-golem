# Content and prestige (#15)

Status: six-zone configuration and Ascension implemented; Studio balance pending.
See [playtest.md](playtest.md). The ≥20-hour completion path is **not measured**.

## Islands and forge

| Island | Gate | New mineral / tiers | Boss |
| --- | --- | --- | --- |
| Mossy Quarry | Start | Stone, Copper | Old Rockjaw |
| Ember Flats | Rockjaw | Iron | Slag Matron |
| Glasswood | Matron + size 3 | Crystal | Prism Stag |
| Storm Peak | Stag + size 4 | Stormglass | Thunder Roc |
| Sunken Ruins | Roc + size 5 | Abyssite | Tide Sentinel |
| Sky Forge | Sentinel + size 6 | Sunsteel, Aether | Solar Colossus |

Each island has a swarmer and a slower tank. Existing enemy IDs stay valid for
quests. Spawn weights live on Config.Enemies (default 1); base enemies have a
3:1 ratio against tanks. Tanks have twice the health, XP and mineral payout,
and 60% movement speed. Every twentieth successful regular spawn on an island is
an elite (2x health, 1.4x damage, 3x XP/minerals, 1.25x size, gold outline and
"Elite" name). This counter resets with the server; it is not a random reward
roll. Artifact odds and pity are unchanged, including for elites.

Each added island has six artifacts: four enemy drops, one boss, one hidden.
All sources use the existing shown odds, pity, set bonuses and bound-copy rules.
No paid access gates. The level cap is 100, with additional size milestones at
40, 55, 75 and 100. New themes currently reuse the existing scenery palettes;
unique atmospheric effects remain art polish work.

## Ascension specification and implementation

The Awaken tab contains a separate Ascension section. Eligibility requires five
**unspent** Awakenings and defeating the zone 6 boss in this run.
A second tap confirms the clearly listed reset. The server rechecks requirements;
the client cannot grant points or bypass the boss gate.

An Ascension marks five Awakenings as spent for future Ascension eligibility and resets level/XP, forged parts, skills,
minerals and boss victories, returning to zone 1. It grants one permanent point.
Artifacts, equipped artifacts, pity, spare copies, cosmetics, receipts, quests,
other reward history, lifetime Awakening count and its mineral bonus, shards and shard upgrades survive.
Each point buys one rank in Titan Vigor (+10% health/damage), Ancient Insight
(+10% XP), or Sky Harvest (+10% minerals/mining); each has ten ranks. These are
additive bonuses in the same computation as other bonuses. No Robux purchase.
Existing saves reconcile an empty Ascension record; no store migration.

Awakening count remains a lifetime total: Ascension tracks `spentAwakenings`
separately, so earning five more enables the next Ascension. Existing mineral
bonuses, titles and cosmetic eligibility survive. This keeps prestige a permanent
gain. The run's boss gate must be completed again after each Ascension.

## Co-op tower design (not implemented)

A private party challenge accessed through Travel. The party leader selects a
fixed ten-wave route, all members accept with buttons, and the run starts only
when each participant is eligible and present. Solo entry remains available.
Use an isolated arena per party, with no damage/reward sharing across arenas.
No text entry, paid tickets, paid revives, random chests or purchase countdowns.

- Snapshot the party at entry; later invites do not join mid-run. Leaving forfeits
  uncompleted waves, never currency already awarded. End cleanly on disconnect.
- Spawn weighted existing enemies, a boss on waves 5 and 10, and cap total models
  to the normal per-player budget. Reuse the readable dodge circle.
- Fixed mineral/XP wave rewards, stated before entry. Award once per wave per run
  on the server; retries and duplicate death callbacks cannot pay twice.
- Keep difficulty, rewards, wave count and arena limits in Config. Do not add
  random rewards without shown odds and pity.
- Require three-client tests for leadership changes, disconnects, concurrent
  arenas, reset/exploit attempts, and low-end-phone performance before enabling.

This is a design proposal; the issue requests a co-op design document, not a
shipped side mode. Tune its reward rate after base-game timing data exists.
