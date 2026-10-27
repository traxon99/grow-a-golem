# Social and co-op

Last updated: 2026-10-27. Read [safety-compliance.md](safety-compliance.md) first; it overrides this doc.

## Rules for agents

1. **Social features must work without text chat.** Many 9-15 players cannot chat (age check required, age bands); use parties, emotes, pings and shared goals ([Roblox newsroom, Nov 2025](https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat)).
2. **Before any trade, check `IsPaidItemTradingAllowed`** on the server; if false, block trading of paid items and paid-random outcomes ([Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)). Fail closed.
3. **Trades need two-sided confirmation and a value warning;** no trading of Robux-bought items at launch (house rule, inference).
4. **Filter any player-entered text** (party names, signs, golem names) with `TextService` on the server ([Text filtering](https://create.roblox.com/docs/ui/text-filtering.md)).
5. **No social media links in-experience** ([Roblox newsroom, Nov 2025](https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat)).
6. **No pay-to-grief:** nothing bought with Robux may harm, fling, steal from or block another player (house rule; see Steal a Brainrot in [monetization.md](monetization.md)).
7. **No hangout or free-form drawing features;** they exclude the game from Kids/Select accounts ([Roblox newsroom, June 2026](https://about.roblox.com/newsroom/2026/06/age-based-roblox-kids-and-select-accounts-now-globally-available)).
8. **Friend bonuses reward playing together, not inviting strangers** (inference).

## What top games do

- **Trading drives value** in Pet Sim, Blox Fruits and Grow a Garden. Blox Fruits even lets passes be traded ([Blox Fruits wiki](https://blox-fruits.fandom.com/wiki/Shop)). Grow a Garden shipped a Trading Update (Aug 2, 2025) with trade tickets; details not retrieved ([Deltia's Gaming, metadata only](https://deltiasgaming.com/?p=304155)).
- **Trading also feeds real-money trading and scams:** rare Grow a Garden items sell on eBay and Discord against Roblox terms ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)).
- **Co-op bonuses:** Grow a Garden gives +10% sell value when playing with friends (fan guide, [itemlevel.net](https://itemlevel.net/complete-beginners-guide-for-grow-a-garden-roblox/)). 99 Nights is built around co-op survival ([PC Gamer](https://pcgamer.com/games/roblox/99-nights-in-the-forest-tips/)).
- **Chat and age:** since January 2026 chat needs a facial age check (or ID), with bands under 9, 9-12, 13-15, 16-17, 18-20, 21+; chat only with similar ages; off by default for under-9s ([Roblox newsroom, Nov 2025](https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat)). As of Q2 2026, 57% of DAU had age-checked and on-platform communication had not recovered ([Q2 2026 letter](https://www.sec.gov/Archives/edgar/data/0001315098/000162828026051059/ex991-robloxq22026earnin.htm)).
- **Biggest social moments are live events:** the Aug 2025 "admin abuse war" between Grow a Garden (22.3M CCU) and Steal a Brainrot (20.1M) pushed Roblox to a record of about 47M concurrent players ([Lenovo Legion Gaming](https://gaming.lenovo.com/roblox/post/roblox-just-shattered-the-all-time-record-for-concurrent-players-8s7u0nswtSVrLpi); [Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)).
- **Private servers:** free or monthly Robux; Roblox Plus members get one free paid private server per game, unlimited where the creator makes them free ([Private servers](https://create.roblox.com/docs/en-us/production/monetization/private-servers.md); [PCGamesN](https://www.pcgamesn.com/roblox/plus-private-server-limit)).
- **Leaderboards and griefing:** Steal a Brainrot's core is stealing from other bases, and some paid gear flings players ([Deltia's Gaming](https://deltiasgaming.com/roblox-steal-a-brainrot-all-gear-and-game-passes)). We do not copy this.
- Not verified: server size norms, specific trade safeguards in top games, friend-invite reward implementations.

## Grow A Golem today

- Co-op parties up to 4; kills within 80 studs are shared.
- Friend bonus +10% per friend, up to +30%.
- Global leaderboards.
- **Golem Hub (#13):** a safe island (zone id 0, `Config.Hub`, Travel tab) with no enemies. Golems idle there on show. Walking up to a golem shows an Inspect prompt (also the Hub tab list): level, size, Awakenings, parts, equipped artifacts, found count, bosses beaten. No hangout, drawing or free-text features.
- **Titles:** 8 earned titles in `Config.Titles` (boss kills, zone collections, Awakening, level 30) worn on the nametag. Never sold, no player-entered text, so no TextService filtering is needed.
- **Rare-find shout:** boss and hidden-relic artifact finds are announced to the server unless a player turns announcements off in the Hub tab (`data.social.announce`).
- **Trading (`TradeService`, Trade tab):** spare artifact copies only. Once every artifact from an island source is found, the same drop odds and pity give spare copies (shown in the Artifacts menu and Shop). Fail-closed `IsPaidItemTradingAllowed` gate, friends or party members only, account at least 7 days old, 10 trades per UTC day, both players Ready then a 5 second countdown then both Confirm, any change resets, lopsided-trade warning, atomic swap that re-checks both saves with no waiting, a trade log keyed by UserId in both saves. Spares found under Robux-bought 2x Luck are bound and never tradable. No minerals, no cosmetics, no text.
- No player-entered text visible to others; no chat features beyond Roblox default.

## Gaps worth closing

1. ~~**P1 (#13):** Hub design with no hangout or drawing features.~~ Done. Emotes and pings are still open.
2. ~~**P1 (#13):** If trading ships: `IsPaidItemTradingAllowed` gate, two-sided confirm, value warning, trade log keyed by UserId, no trading of Robux-bought items.~~ Done. Known limit: saves use plain DataStore calls without session locking, so if one of the two saves right after a trade fails while the other succeeds, a copy could be duplicated or lost. Moving to ProfileStore fixes it.
3. **P1:** Co-op world boss or shared event so parties have a reason to form (also [live-ops.md](live-ops.md)).
4. **P2:** Free private servers (goodwill; inference).
5. **P2:** Make sure leaderboards show only Roblox display names and can drop a user on RTBF.

## Sources

All accessed 2026-10.
- Roblox newsroom, age checks and chat (Nov 2025): https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat
- Roblox newsroom, Kids and Select accounts (June 2026): https://about.roblox.com/newsroom/2026/06/age-based-roblox-kids-and-select-accounts-now-globally-available
- Roblox Creator Docs, Paid random items: https://create.roblox.com/docs/production/monetization/paid-random-items
- Roblox Creator Docs, Text filtering: https://create.roblox.com/docs/ui/text-filtering.md
- Roblox Creator Docs, Private servers: https://create.roblox.com/docs/en-us/production/monetization/private-servers.md
- Roblox Q2 2026 shareholder letter: https://www.sec.gov/Archives/edgar/data/0001315098/000162828026051059/ex991-robloxq22026earnin.htm
- Blox Fruits Wiki, Shop: https://blox-fruits.fandom.com/wiki/Shop
- Deltia's Gaming, Grow a Garden trading update: https://deltiasgaming.com/?p=304155
- Deltia's Gaming, Steal a Brainrot gear and passes: https://deltiasgaming.com/roblox-steal-a-brainrot-all-gear-and-game-passes
- Wikipedia, Grow a Garden: https://en.wikipedia.org/wiki/Grow_a_Garden
- itemlevel.net, Grow a Garden beginner guide: https://itemlevel.net/complete-beginners-guide-for-grow-a-garden-roblox/
- PC Gamer, 99 Nights tips: https://pcgamer.com/games/roblox/99-nights-in-the-forest-tips/
- Lenovo Legion Gaming, CCU record: https://gaming.lenovo.com/roblox/post/roblox-just-shattered-the-all-time-record-for-concurrent-players-8s7u0nswtSVrLpi
- PCGamesN, Roblox Plus private server limit: https://www.pcgamesn.com/roblox/plus-private-server-limit
