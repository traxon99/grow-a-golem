# Concept review: uniqueness, gaps and market odds (#153)

Written 2026-10-28 at commit `edc8013`. Player counts are third-party tracker snapshots from that week. They're good for comparing games but not exact. The live, editable version is the [Claude Doc](https://claude.ai/artifact/Mm5HUGF7j4U1JEQFYJ6Qc1).

## Verdict

The gameplay is more original than the name suggests, but the game has never been played, and that is the biggest risk. Riding on your golem's shoulder while it grows into a titan and fights across islands is a real hook. Neither Build A Golem! nor Grow a Garden does that. The "Grow a" name works against the game, though. It signals a Grow a Garden clone at a time when that brand is fading, and it sits right next to Build A Golem!, a well-rated golem game that launched in June 2026.

- **Uniqueness:** medium to high on mechanics, low on name and theme.
- **Biggest gaps:** it hasn't been playtested, there's no shared moment that pulls players together every few minutes, growth may not be visible enough, and friends have little reason to invite each other.
- **Market odds:** a viral breakout is very unlikely. A realistic good outcome is hundreds to a few thousand players online at once, which is roughly where Build A Golem! sits. That is a judgment call based on comparable games, not a forecast.

## What the concept is today

Grow A Golem is a nearly feature-complete 3D idle auto-battler (about 18,000 lines of Luau), but it hasn't been published or played in Studio yet.

- **Core fantasy:** you ride on your golem's shoulder. Leave the controls alone and it fights and mines by itself. You can also steer it and cast Quake, Mend and Magnet.
- **Progression:** you forge parts into 5 slots across 8 mineral tiers. The golem grows at level milestones, up to level 100. There are 6 floating islands, each gated by a boss and the golem's size, with a telegraphed slam you can dodge.
- **Collection and meta:** 36 artifacts with shown odds and a pity counter, a 3-branch skill tree, Awakening (rebirth) and Ascension (prestige).
- **Social:** parties of up to 4, a friend bonus, a Hub where players can inspect each other's golems, safe trading of spare artifacts, and a co-op Golem Tower that is built but turned off.
- **Retention and live ops:** daily streaks, daily and weekly quests, session gifts, offline mining, codes, scheduled events with free reward tracks, and analytics funnels.
- **Monetization:** 5 passes (R$149 to R$399), mineral packs, 30-minute boosts, and paid cosmetics bought directly, with no loot boxes. None of these have been created on Roblox yet (#50).
- **Status:** [playtest.md](playtest.md) says "not played in Studio." Pacing, the 20-hour completion target and mobile performance haven't been measured.

## Uniqueness

No existing Roblox game combines riding a growing golem with idle auto-battling and boss fights you dodge yourself. That combination is the distinct part. The golem theme and the "Grow a" name are both taken.

| Game | Core loop | Peak players online | Players online now | Overlap with Grow A Golem |
| --- | --- | --- | --- | --- |
| [Build A Golem!](https://www.rotrends.com/game/10399524075) (June 2026) | Roll for golem parts, assemble them, park golems on ore plots for offline cash | ~9.7K | ~200 to 750 | Same theme and part upgrades, but it has no riding, combat or growth. Golem players have already seen it. |
| [Build a Golem Army!](https://www.rolimons.com/game/81525595245099) (March 2025) | Buy golem spawners, battle other kingdoms, rebirth | 4.1K | ~75 | Same golems-plus-combat theme, but it's dead now |
| [Grow a Garden](https://rovitals.com/game/126884695634066) (2025) | Plant, harvest, sell; 5-minute restocks, weather, events | 22M+ | ~14K to 20K, down 29% in 30 days | The name only. Its Golem pet is already familiar to its players. |
| [Grow a Garden 2](https://rowatcher.com/games/10200395747/grow-a-garden-2) (May 2026) | Sequel to Grow a Garden | 976K | ~800 | Shows that even official "Grow a" sequels fade within months |
| [Grow Dinosaurs](https://rowatcher.com/games/7656308490/grow-dinosaurs) (May 2025) | Hatch, feed, raise, sell dinos | 238 | ~13 | A plain "grow a creature" game with no hook stays tiny |

- **What's distinct:** the shoulder-ride camera, a golem that physically grows (+25% scale per size step), and combat that works both idle and active. This is the kind of remix, changing one big element of a proven loop, that tends to beat straight clones.
- **What's not:** the forge-and-tier progression, rebirth, artifacts with odds, codes and weekly events are the standard simulator package. That's fine, because players expect it, but it doesn't set the game apart.
- **The name problem:** "Grow A Golem" reads as a Grow a Garden clone, and the thumbnail will sit next to Build A Golem! in search. Players may assume it's a knockoff of one or both. A name built around the riding or titan fantasy would set it apart better. Test the name as well as the icon (#152).

## Gaps, ranked

The biggest gap is evidence, not features. Everything below except the first item is a design call that a playtest would confirm or rule out.

| # | Gap | Tracked in |
| --- | --- | --- |
| 1 | **No one has played it.** Time to first fight, time to first forge, minutes per island and phone performance are all unknown. That's 149 merged PRs on a loop no player has touched. Most hits shipped a small core in days and built on it from player data. | #9, #39 to #45 |
| 2 | **The idle loop may not be fun without its rewards.** "The golem plays itself" is convenient, but it risks a boring core action, a pattern that tends to collapse around day 7. The active layer (steering, spells, dodging slams) has to feel good within the first 60 seconds, or players bounce. | #81 |
| 3 | **No shared moment.** There's no global timer, world boss or surge that pulls a server together every few minutes. Grow a Garden's 5-minute restocks and its "admin abuse" events drove its records. | #150 |
| 4 | **Growth may not be visible enough.** Per-tier golem models landed in #120, but nobody has checked in play whether the first forge and each size step look like a big jump. Growth is the whole premise of the name and the thumbnail. | #39, #45 |
| 5 | **Weak reasons to invite friends.** Parties share kills and give +10% per friend, but the Tower is off and there's no co-op boss. Roblox's 28-day ranking rewards co-play, and nothing here needs a friend. | #150, #42 (to turn the Tower on) |
| 6 | **Rebirth is thin.** Awakening gives +10% minerals and unlocks no new system, while Pet Simulator 99 gives about +75% per rebirth. | #151 |
| 7 | **Visuals are judged by the icon and thumbnails** next to Build A Golem!, and the key art is still illustrations, not real gameplay captures. | #54 |
| 8 | **Nothing stands out to sell.** Every pass is a standard time-saver, and cosmetics are the planned growth line. That suits players aged 9 to 15, but expect spend per player near the genre's low end. | — |

## Market odds

The most likely result is a small, steady game with tens to a few hundred players online at once. Anything bigger depends on retention numbers that don't exist yet. The likelihoods below are judgment from comparable games, not a model.

| Outcome | Players online at once | What it would take | Estimate |
| --- | --- | --- | --- |
| Viral hit | 100K+ | A meme-able hook, an operator such as DoBig or Splitting Point backing it, and admin-abuse events | Under 1% |
| Breakout | 5K to 20K | D1 retention near the top 2% of games (~32%) and Roblox Home recommendations | ~5% |
| Solid niche | 300 to 3K | D1 around 18%, weekly updates, decent thumbnails. Build A Golem! lives here. | ~25% |
| Small or quiet | Under 300 | The default for most launches | ~70% |

- **Working for it:** simulation holds about 45% of live players, play is spreading away from the top 10 games, and 28% of the top 100 games in August 2026 had launched within the previous 90 days. The repo's safety design, analytics and event tools are ahead of most indie launches, and they suit Roblox's 28-day retention ranking.
- **Working against it:** simulation averages only 227 players per game across 15,236 games. Grow-a titles are falling. Build A Golem! already owns golem search. The median paid creator earned about $1,500 in the year to June 2026.
- **Benchmarks for the ad test (#60):** about 18% D1 and 5% D7 is the 90th percentile, and 32% and 8.5% is the top 2% ([InvestGame/GameAnalytics](https://investgame.net/news/pdf/the-2025-roblox-benchmark-report/)). The launch plan's "fix before scaling" line of D1 under 15% fits these benchmarks.

## Recommended next steps

Stop adding systems and get real players into the first 10 minutes. Everything else depends on that data.

1. Run the Studio playtest in [playtest.md](playtest.md) and record time to first fight, first forge and first boss (#39, #45). The targets are under 10 seconds and under 2 minutes.
2. In that playtest, check that the first forge and every size step look like a big jump, so the growth fantasy lands early.
3. Add one shared, free beat every 10 to 15 minutes, and use it for co-op as well (#150).
4. Pick a working title that leads with the riding or titan fantasy, and test it against "Grow A Golem" (#152).
5. Replace the illustrated thumbnails with real gameplay captures that show a small golem next to a huge one (#54).
6. Run the capped $50 ad test from [launch/plan.md](launch/plan.md) and compare D1 and D7 to the benchmarks above before spending more (#60).

## Sources

Accessed 2026-10-28.

- [Build A Golem! stats (RoTrends)](https://www.rotrends.com/game/10399524075), [Bloxodes](https://bloxodes.com/stats/games/build-a-golem-10399524075), [getting-started wiki](https://buildagolem.wiki/guides/getting-started/), [Destructoid](https://www.destructoid.com/build-a-golem-codes/)
- [Build a Golem Army! (Rolimons)](https://www.rolimons.com/game/81525595245099)
- [Grow a Garden (RoVitals)](https://rovitals.com/game/126884695634066), [Grow a Garden 2 (RoWatcher)](https://rowatcher.com/games/10200395747/grow-a-garden-2), [Grow Dinosaurs (RoWatcher)](https://rowatcher.com/games/7656308490/grow-dinosaurs)
- [Golem pet in Grow a Garden (Sportskeeda)](https://www.sportskeeda.com/roblox-news/what-golem-grow-garden)
- [InvestGame/GameAnalytics 2025 Roblox benchmark report](https://investgame.net/news/pdf/the-2025-roblox-benchmark-report/)
- Genre shares, creator earnings and the 28-day ranking change: [Statroblox genre guide](https://statroblox.com/guides/most-popular-roblox-genres), [Roblox Newsroom on 28-day discovery](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox), [DevForum RDC26](https://devforum.roblox.com/t/rdc26-what-we-announced/4865880), [IBTimes UK on creator payouts](https://www.ibtimes.co.uk/roblox-top-creators-devex-payouts-2026-1819403)
