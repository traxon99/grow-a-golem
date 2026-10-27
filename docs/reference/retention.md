# Retention

Last updated: 2026-10-27. Read [safety-compliance.md](safety-compliance.md) first; it overrides this doc.

## Rules for agents

1. **Retention hooks are gameplay, never purchase pressure.** No countdowns or "today only" Robux offers attached to streaks, events or gifts (house rule; see safety doc).
2. **Streaks forgive.** A missed day should not wipe a 9-15 player's streak to zero; prefer pause or step-back (inference, modeled on Adopt Me's forgiving streak, [Sportskeeda](https://www.sportskeeda.com/roblox-news/adopt-me-pets-plus-subscription-benefits-content-price)).
3. **Codes are free** and never require following, liking, favoriting or buying. **No rewards for likes or favorites.**
4. **Random rewards from gifts, quests or events show real odds and have pity.** If a boost is active, displayed odds update live.
5. **Offline gains stay below active rates** and are capped; show a "welcome back" claim screen (inference, see below).
6. **Do not rely on push notifications.** Experience notifications reach only opted-in users 13+, max 1 per day, and may not use false time pressure ([Experience notifications](https://create.roblox.com/docs/production/promotion/experience-notifications.md)).
7. **Every retention feature logs an analytics event** (claim, skip, streak break) so it can be tuned (#11).
8. **Gifts, streaks and event rewards never include paid random items for cosmetics, "only/just X Robux" upsells, or social media links;** any paid boost shown in a retention screen follows the PolicyService and live-odds rules in [safety-compliance.md](safety-compliance.md).
9. **Show short, mid and long-term goals on screen at all times** ([Roblox Docs: Retention](https://create.roblox.com/docs/en-us/production/analytics/retention.md)).

## What top games do

### Benchmarks to aim at
GameAnalytics 2025 Roblox benchmark (Jan 2023 to Jul 2025), by average session length; median / 90th percentile ([GameAnalytics PDF](https://investgame.net/wp-content/uploads/2025/09/2025-Roblox-Benchmark-Report.pdf)):

| Session length | D1 | D7 |
|---|---|---|
| 0-3 min | 4.31% / 9.25% | 0.41% / 1.78% |
| 7-12 min | 7.91% / 11.55% | 0.90% / 2.04% |
| 19-24 min | 11.46% / 18.20% | 1.61% / 5.15% |
| 25+ min | 10.76% / 18.86% | 1.82% / 5.86% |

- Median 2 sessions per user per day; 95th-percentile session about 37 min (same source).
- Inferred targets for us: D1 above 11%, stretch 18%; D7 above 1.6%, stretch 5%; average session 19+ min.

### Tools that work
- **Daily quests feeding a season pass:** Grow a Garden uses 6 daily quests at 250 XP each over a 50-level free + premium track ([Sportskeeda](https://www.sportskeeda.com/roblox-news/grow-garden-season-1-pass-all-tier-rewards-premium-price)).
- **Weekly exclusives you must be online to claim**, and rotating shop stock ([Wikipedia: Grow a Garden](https://en.wikipedia.org/wiki/Grow_a_Garden)). Seed shop restocks every 5 minutes globally (fan guide, [itemlevel.net](https://itemlevel.net/complete-beginners-guide-for-grow-a-garden-roblox/)).
- **Timed return gifts:** PS99 VIP gives a reward chest every 6 hours ([PS99 wiki](https://pet-simulator.fandom.com/wiki/Gamepasses_(Pet_Simulator_99))).
- **Offline progress:** Grow a Garden crops grow while offline ([esports.gg](https://esports.gg/news/roblox/grow-a-garden-breaks-blox-fruits-record-for-most-concurrent-users-on-roblox/)). AFK portals in anime TD games pay every best-clear interval ([allthings.how](https://allthings.how/anime-expeditions-afk-mode-in-roblox-how-the-afk-world-works/)).
- Claimed design rules (low confidence, [RoWatcher](https://rowatcher.com/news/the-afk-revolution-how-idle-mechanics-conquered-roblox)): offline gains near but below active rates (PS99 said to be about 50%, unverified); show per-hour readouts; make a 5-minute check-in satisfying; Robux should compress time, not gate content.
- **Roblox's own advice:** for D1, short tutorial and a satisfying moment after the first loop; for D7, short and long-term goals, content variety, balanced progression; small updates every 2-4 weeks, big ones every 2-3 months ([Retention](https://create.roblox.com/docs/en-us/production/analytics/retention.md)).
- **Notifications:** opt-in, 13+ only, 1 per day per experience, `PromptOptIn()` at most once per 30 days, game needs 100+ visits ([Experience notifications](https://create.roblox.com/docs/production/promotion/experience-notifications.md)). Many of our players are under 13, so in-game hooks matter more (inference).
- Roblox discovery (Apr 2026) now weighs long-term retention signals ([Roblox newsroom](https://about.roblox.com/newsroom/2026/04/roblox-fuels-high-fidelity-games-over-18-players-increases-qualifying-devex-rate-42)).

## Grow A Golem today

Feature coverage is already broad:
- 7-day daily login streak (reset behavior on a missed day: check code).
- 3 daily quests plus weekly quests.
- Session playtime gifts at 5/15/30/60 min.
- Offline mining: 2h cap base, 12h with Long Rest pass. Rate vs active not documented here.
- Group join reward (group id not set yet).
- Redeemable codes, rate-limited.
- Limited-time events with free event-currency reward tracks; weekly Double Minerals Weekend; progress carries over.
- Next-goal tracker under the golem health bar (short-term goal visible).
- Missing: analytics to measure any of it (#11), no playtest yet (#9), no season-pass-style long track, no "welcome back" summary confirmed.

## Gaps worth closing

1. **P0 (#11):** Instrument D1/D7, session length, quest completion, gift claims and streak breaks. Without data the targets above are guesses.
2. **P0 (#9):** Playtest that the 5-minute gift lands near the first forge and the next-goal tracker always shows something.
3. **P1:** Make the login streak forgiving (pause or step back one day) if it currently resets.
4. **P1:** "Welcome back" panel showing offline minerals and time away; keep offline rate below active (target about 50%, inference).
5. **P1 (#12):** Set the group id; keep codes free and announced in-game.
6. **P2 (#15):** A free reward track spanning a season fed by daily quests, as Grow a Garden does; any premium track optional, no level skips for Robux.
7. **P2:** Long-term goal surface (artifact collection %, next awakening).

## Sources

All accessed 2026-10.
- GameAnalytics 2025 Roblox Benchmark Report: https://investgame.net/wp-content/uploads/2025/09/2025-Roblox-Benchmark-Report.pdf
- Roblox Creator Docs, Retention: https://create.roblox.com/docs/en-us/production/analytics/retention.md
- Roblox Creator Docs, Experience notifications: https://create.roblox.com/docs/production/promotion/experience-notifications.md
- Sportskeeda, Grow a Garden Season 1 Pass: https://www.sportskeeda.com/roblox-news/grow-garden-season-1-pass-all-tier-rewards-premium-price
- Sportskeeda, Adopt Me Pets Plus: https://www.sportskeeda.com/roblox-news/adopt-me-pets-plus-subscription-benefits-content-price
- Wikipedia, Grow a Garden: https://en.wikipedia.org/wiki/Grow_a_Garden
- itemlevel.net, Grow a Garden beginner guide: https://itemlevel.net/complete-beginners-guide-for-grow-a-garden-roblox/
- esports.gg, Grow a Garden CCU record: https://esports.gg/news/roblox/grow-a-garden-breaks-blox-fruits-record-for-most-concurrent-users-on-roblox/
- Pet Simulator Wiki, Gamepasses (PS99): https://pet-simulator.fandom.com/wiki/Gamepasses_(Pet_Simulator_99)
- allthings.how, Anime Expeditions AFK mode: https://allthings.how/anime-expeditions-afk-mode-in-roblox-how-the-afk-world-works/
- RoWatcher, AFK revolution (low confidence): https://rowatcher.com/news/the-afk-revolution-how-idle-mechanics-conquered-roblox
- Roblox newsroom, discovery changes (Apr 2026): https://about.roblox.com/newsroom/2026/04/roblox-fuels-high-fidelity-games-over-18-players-increases-qualifying-devex-rate-42
