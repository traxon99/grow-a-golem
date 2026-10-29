# Progression

Last updated: 2026-10-27. See also [gameplay-loops.md](gameplay-loops.md) and [monetization.md](monetization.md).

## Rules for agents

1. **Keep all curve numbers in `src/shared/Config.luau`;** never hard-code thresholds in services or UI.
2. **Early levels come fast:** low early XP thresholds, then steepen ([Roblox Docs: Onboarding](https://create.roblox.com/docs/production/game-design/onboarding.md)).
3. **A rebirth (Awakening) must feel like a gain, not a loss:** a permanent multiplier big enough to notice plus a new feature or system unlocked (pattern from PS99 below; inference for our numbers).
4. **Gates are explicit and shown on screen:** what is needed for the next zone (size, boss kill) with a progress bar.
5. **Rarity tiers step by roughly 10x in value** as a readable default (inference from Steal a Brainrot income tiers).
6. **Collections have a visible completion count** (x/18 artifacts) and set rewards (pattern: PS99 Index, Fisch bestiary).
7. **Large numbers use one K/M/B/T formatter** (common practice, unverified; see [ui-ux.md](ui-ux.md)).
8. **Random progression rewards show real odds and pity;** paid modifiers follow [safety-compliance.md](safety-compliance.md).
9. **Track how many players reach each level/zone** and retune the steps that stall ([Roblox Docs: Retention](https://create.roblox.com/docs/en-us/production/analytics/retention.md)).
10. **Never sell a progression gate** (house rule). Robux may speed it, not skip it.

## What top games do

### Rebirth / prestige
- **PS99:** rebirths sit at fixed area milestones (Area 25, 50, 75, 99, ...); Rebirths 1-8 each give +75% pet strength and each unlocks a system: R1 teleport and trading plaza, R2 clans and auto-hatch, R3 pet teams and Index rewards, R4 Ultimates and Mastery, R5 secret pets, R6 golden and charged eggs ([Hold To Reset](https://holdtoreset.com/pet-simulator-99-rebirth-system-explained/); the guide's rebirth count is inconsistent).
- **Steal a Brainrot:** rebirth wipes units but grants a permanent earnings multiplier and tokens for more pedestals (up to 40), skins and VIP zones; from rebirth 3, Golden variants earn 4x and Rainbow 6x; first rebirth suggested after about 8-10 hours ([playnews.gg](https://www.playnews.gg/en/guides/steal-a-brainrot-roblox-the-complete-strategy-rebirth-and-tier-list-guide-for-july-2026), fan guide).
- **99 Nights:** diamonds from achievements and codes buy persistent classes (e.g. Scavenger, 25 diamonds) between runs ([PC Gamer](https://pcgamer.com/games/roblox/99-nights-in-the-forest-tips/)).

### Zone gating
- **Blox Fruits:** Second Sea at level 700 plus a quest chain; Third Sea at level 1,500 plus a boss chain ([Pro Game Guides](https://progameguides.com/roblox/all-sea-requirements-in-blox-fruits-explained-roblox/)).
- **Fisch:** Jetski needs level 50; Second Sea quest at level 200, where First Sea currency stops working; 12+ islands ([Destructoid](https://www.destructoid.com/fisch-roblox-beginners-guide/)).
- **Grow a Garden:** gear prices step up (Basic Sprinkler $20,000, Watering Can $50,000) (fan guide, [itemlevel.net](https://itemlevel.net/complete-beginners-guide-for-grow-a-garden-roblox/)).

### Rarity ladders and collections
- Steal a Brainrot income per second by tier (fan guide, July 2026): Common $1-5, Rare $25-100, Epic $250-1,000, Legendary $3,000-10,000, Mythic up to $50,000, Brainrot God over $200,000, roughly 10x per tier ([playnews.gg](https://www.playnews.gg/en/guides/steal-a-brainrot-roblox-the-complete-strategy-rebirth-and-tier-list-guide-for-july-2026)).
- PS99 tier names: Basic, Rare, Epic, Legendary, Mythical, Exotic, Divine, Superior, Celestial; each rank has a reward path unlocking equip, egg and enchant slots ([PS99 wiki: Ranks](https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99))).
- Grow a Garden seeds: Common, Uncommon, Rare, Legendary, Mythical, plus secret ([itemlevel.net](https://itemlevel.net/complete-beginners-guide-for-grow-a-garden-roblox/)).
- Number inflation risk: PS99 has had gem value corrections and economy resets ([RoWatcher, low confidence](https://rowatcher.com/news/the-afk-revolution-how-idle-mechanics-conquered-roblox)).
- No verified XP-curve formulas from top games were found.

## Grow A Golem today

- Max level 100; total XP to reach level L = `25*(L-1)^1.6` (level 10 about 840, level 20 about 2,780, level 60 about 17,000).
- Golem size steps at levels 1/5/10/18/28/40/55/75/100 (each +25% model scale) gate zones together with boss kills.
- Forge: 5 part slots x 8 tiers (stone, copper, iron, crystal, stormglass, abyssite, sunsteel, aether) with a full-set bonus.
- Skill tree: 3 branches x 8 nodes; respec costs stone.
- **Awakening** (rebirth) from level 20: shards = level - 15; +10% minerals per awakening; shard upgrades.
- **Awakening unlocks (#151):** Awakening 1 gives a free Auto-Forge, Awakening 2 an extra artifact slot (stacks with the Extra Artifact Slot pass), Awakening 3 the earned "Runebound" title (`Config.AwakeningUnlocks`). They count lifetime Awakenings, so Ascending keeps them. The Awaken tab lists them with the next one marked, and the Awaken button and its confirm dialog name what the next Awakening unlocks. The Shop's Auto-Forge pass says "Free after Awakening 1" and shows "Unlocked" instead of a price once a player has it free; the paid passes still work for players who want them sooner.
- 36 artifacts across six islands (drop, boss, hidden), drawn from marble bags (1 in 167 per enemy, 1 in 3 per boss, a find sure within each bag; 2x Luck halves the bag; #156), zone set bonuses, odds shown in Artifacts menu and Shop.
- Once every artifact from an island source is found, the same bag (shown in the menus) gives a spare copy instead (`Stats.spareOdds`), drawn from a spare bag so each comes up once before repeats. Spares are tradable (see social.md), except those found under Robux-bought 2x Luck. Titles (`Config.Titles`) are earned from boss kills, zone collections, Awakening and level 30.
- Compared with norms: structure matches the genre. Awakening's +10% minerals is small next to PS99's +75% per rebirth; the first three Awakenings now each unlock something, but later ones add only the multiplier and shards. Later growth milestones now extend to level 100.

- **Expansion (#15):** six islands with two weighted enemy types each, periodic deterministic elites, eight tiers, new skill nodes and later growth. Analytics also logs Ascension completion. Ascension requires five unspent Awakenings plus the zone 6 boss; it resets the current run, preserves lifetime Awakening bonuses and collections, and grants a point for a permanent three-branch upgrade tree. See [expansion-design.md](../expansion-design.md).
- **Validation:** offline syntax/logic checks cover level boundaries, free gate/resource reachability, odds/marble bags and actual Ascension handlers. Studio pacing and the 20-hour completion goal remain unmeasured; use [playtest.md](../playtest.md).

## Gaps worth closing

1. **P1 (#15):** ~~Make each Awakening unlock something new~~ Done for Awakenings 1 to 3 in #151 (auto-forge, extra artifact slot, title). Still open: unlocks past Awakening 3, and a larger base multiplier set from the #45 timing runs. Test in #9.
2. **P1:** Add milestone rewards between levels 28 and 60 (size steps, titles, cosmetic unlocks) so late levels have goals.
3. **P1:** Artifact collection screen with x/18, set progress, and pity progress per source.
4. **P1 (#11):** Log level, zone and awakening reached per player to find stalls.
5. **P2:** Shared number formatter (also in [ui-ux.md](ui-ux.md)).
6. **P2 (#15):** More zones and tiers before numbers inflate; plan the ceiling to avoid an economy reset.

## Sources

All accessed 2026-10.
- Roblox Creator Docs, Onboarding: https://create.roblox.com/docs/production/game-design/onboarding.md
- Roblox Creator Docs, Retention: https://create.roblox.com/docs/en-us/production/analytics/retention.md
- Hold To Reset, PS99 rebirth system: https://holdtoreset.com/pet-simulator-99-rebirth-system-explained/
- playnews.gg, Steal a Brainrot guide (July 2026): https://www.playnews.gg/en/guides/steal-a-brainrot-roblox-the-complete-strategy-rebirth-and-tier-list-guide-for-july-2026
- PC Gamer, 99 Nights tips: https://pcgamer.com/games/roblox/99-nights-in-the-forest-tips/
- Pro Game Guides, Blox Fruits sea requirements: https://progameguides.com/roblox/all-sea-requirements-in-blox-fruits-explained-roblox/
- Destructoid, Fisch beginner guide: https://www.destructoid.com/fisch-roblox-beginners-guide/
- itemlevel.net, Grow a Garden beginner guide: https://itemlevel.net/complete-beginners-guide-for-grow-a-garden-roblox/
- Pet Simulator Wiki, Ranks (PS99): https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99)
- RoWatcher, AFK revolution (low confidence): https://rowatcher.com/news/the-afk-revolution-how-idle-mechanics-conquered-roblox
