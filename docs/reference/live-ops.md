# Live ops

Last updated: 2026-10-27. Read [safety-compliance.md](safety-compliance.md) first; it overrides this doc.

## Rules for agents

1. **Ship on a fixed cadence:** small updates every 2-4 weeks, big ones every 2-3 months ([Roblox Docs: Retention](https://create.roblox.com/docs/en-us/production/analytics/retention.md)). Weekly is what the 2025 hits did (see below).
2. **Event content is data-driven in Config** (start/end times, multipliers, reward tracks) so an event ships without code changes.
3. **Event timers are for gameplay only.** Never place a purchase offer, "today only" Robux deal, or countdown next to a buy button ([safety-compliance.md](safety-compliance.md)).
4. **Codes are always free,** never require following, liking, favoriting or buying, and are announced in-game (update log, event banner) and on the Roblox group page, never via in-experience social links ([Roblox newsroom, Nov 2025](https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat)).
5. **Event rewards stay earnable for free;** progress carries over or converts so missing a weekend doesn't feel like loss (house rule).
6. **Pair every spike with daily reasons to return:** CCU falls fast after update day (see below).
7. **Random event rewards show odds and have pity,** like all random rewards.
8. **Rotate store thumbnails with each update** (2-5 active; see [art-audio.md](art-audio.md)).

## What top games do

- **Weekly updates set records step by step.** Grow a Garden CCU by update: Blood Moon (May 18, 2025) about 5M; Bizzy Bees (May 31) 11.7M+; Working Bees (June 14) 16M+; Summer Update (June 21) 21.3M (sources conflict); Aug 23 at least 22.3M ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)). It broke its own record two weeks running in June 2025 ([Insider Gaming](https://insider-gaming.com/roblox-grow-a-garden-shatters-all-time-player-record-for-second-week-in-a-row/)).
- **Spikes are short:** after the June 21 peak Grow a Garden fell to 7.6M within an hour; the June 25 average was 2.7M ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)).
- **Two event teams** were formed in July 2025 to keep up with weekly events; weekly exclusives had to be claimed while online (same source).
- **"Admin abuse" live events** handing out exclusives drove the largest moments; Steal a Brainrot hit 24M at its "Extinct Event" (Sept 13, 2025) and 25.4M in Oct 2025 ([Wikipedia: Steal a Brainrot](https://en.wikipedia.org/wiki/Steal_a_Brainrot)). PC Gamer called these events "sensory overload" (same source).
- **Seasonal pass:** Grow a Garden Season 1 ended Nov 1, 2025, fed by daily quests ([Sportskeeda](https://www.sportskeeda.com/roblox-news/grow-garden-season-1-pass-all-tier-rewards-premium-price)).
- **Codes:** 99 Nights gives diamonds through codes and achievements ([PC Gamer](https://pcgamer.com/games/roblox/99-nights-in-the-forest-tips/)). Code distribution practice in top games was not verified.
- **Market shift:** in Q2 2026 Roblox said the 2025 viral hits were declining; the top 10 now take about 20% of hours, down from 30% three years earlier; new hits include Grow a Garden 2 and Kick a Lucky Block ([Q2 2026 letter](https://www.sec.gov/Archives/edgar/data/0001315098/000162828026051059/ex991-robloxq22026earnin.htm)). Concentration in 2025 had risen (top title share of top-10 visits from 22% to 43%) ([Newzoo via GameDevReports](https://gamedevreports.substack.com/p/newzoo-top-roblox-games-in-2025)).
- **Notifications** can announce updates, but only to opted-in 13+ users, once per day max, with no false time pressure ([Experience notifications](https://create.roblox.com/docs/production/promotion/experience-notifications.md)).
- Inference: a fixed weekly update day/time with an in-game countdown concentrates players, which may help discovery. The exact Grow a Garden update weekday (commonly said to be Saturday) was not verified.

## Grow A Golem today

- Limited-time events with free event-currency reward tracks; weekly Double Minerals Weekend; progress carries over.
- Event banner in the HUD.
- Redeemable codes, rate-limited.
- No update log / announcement board found; no fixed update cadence or event calendar written down; no analytics to measure event impact (#11).
- Draft launch copy, an unreleased update log, two icon alternatives, three thumbnail illustrations and a proposed capped ad experiment are in `docs/launch/` and `assets/keyart/`. No ads, group creation, asset upload or game-page publishing has been performed.
- Not yet playtested (#9).

## Gaps worth closing

1. **P1 (#12):** In-game update log and code board as the single place codes and events are announced.
2. **P1 (#12):** Write a 3-month event calendar (weekly small beat, monthly zone or boss event) in Config-driven form.
3. **P1 (#11):** Log event participation, reward-track completion and CCU around updates.
4. **P2 (#15):** A live-hosted or scheduled world-boss event as the "admin abuse" equivalent, free for all, no paid exclusives.
5. **P2 (#16):** Thumbnail and icon refresh per update.

## Sources

All accessed 2026-10.
- Roblox Creator Docs, Retention: https://create.roblox.com/docs/en-us/production/analytics/retention.md
- Roblox Creator Docs, Experience notifications: https://create.roblox.com/docs/production/promotion/experience-notifications.md
- Roblox newsroom, age checks and chat (Nov 2025): https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat
- Wikipedia, Grow a Garden: https://en.wikipedia.org/wiki/Grow_a_Garden
- Wikipedia, Steal a Brainrot: https://en.wikipedia.org/wiki/Steal_a_Brainrot
- Insider Gaming, Grow a Garden record: https://insider-gaming.com/roblox-grow-a-garden-shatters-all-time-player-record-for-second-week-in-a-row/
- Sportskeeda, Grow a Garden Season 1 Pass: https://www.sportskeeda.com/roblox-news/grow-garden-season-1-pass-all-tier-rewards-premium-price
- PC Gamer, 99 Nights tips: https://pcgamer.com/games/roblox/99-nights-in-the-forest-tips/
- Roblox Q2 2026 shareholder letter: https://www.sec.gov/Archives/edgar/data/0001315098/000162828026051059/ex991-robloxq22026earnin.htm
- Newzoo via GameDevReports, top Roblox games 2025: https://gamedevreports.substack.com/p/newzoo-top-roblox-games-in-2025
