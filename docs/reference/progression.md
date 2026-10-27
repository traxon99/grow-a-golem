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

- Max level 60; total XP to reach level L = `25*(L-1)^1.6` (level 10 about 840, level 20 about 2,780, level 60 about 17,000).
- Golem size steps at levels 1/5/10/18/28 (each +25% model scale) gate zones together with boss kills.
- Forge: 5 part slots x 4 tiers (stone, copper, iron, crystal) with a full-set bonus.
- Skill tree: 3 branches x 5 nodes; respec costs stone.
- **Awakening** (rebirth) from level 20: shards = level - 15; +10% minerals per awakening; shard upgrades.
- 18 artifacts (drop, boss, hidden), 0.6% per enemy, 30% per boss, pity 300 enemy / 4 boss rolls, zone set bonuses, odds shown in Artifacts menu and Shop.
- Compared with norms: structure matches the genre. Awakening's +10% minerals is small next to PS99's +75% per rebirth and does not yet unlock a new system. Size step at 28 is the last; levels 29-60 have no size milestone.

## Gaps worth closing

1. **P1 (#15):** Make each Awakening unlock something new (auto-forge, extra artifact slot, new island, cosmetic) in addition to the multiplier; consider a larger base multiplier. Test in #9.
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
