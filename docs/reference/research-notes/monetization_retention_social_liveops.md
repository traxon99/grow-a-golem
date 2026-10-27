# Monetization, Retention, Social/Co-op and Live Ops in Top Roblox Games (2025-2026)

Research date: 2026-10-27. Prices are in Robux (R$) unless stated otherwise. Fandom and guide-site prices may vary by region, because Roblox offers regional and managed pricing, and they can change after an update.

## Monetization: standard pass set, dev products, price points, platform programs, DevEx

### Takeaway
Top games sell 5-15 permanent game passes. Most cost R$175-R$800, with one or two "whale" passes at R$1,200-R$3,250. Each pass is one of a few standard types: 2x currency, auto-farm/auto-tap, VIP, extra slots/storage, luck, or speed/mobility. Repeatable developer products (crates, boosts, skips, currency packs) and a R$700-R$750 season pass sit on top of the passes. At the platform level, Creator Rewards replaced engagement-based Premium Payouts in July 2025. Subscriptions run $2.99-$14.99 a month. Rewarded video ads are shown only to users 13+. DevEx pays $0.0038 per Robux, with a higher $0.0054 rate for spending by age-checked US adults.

### Cited Findings
**Game pass examples with prices**
- **Pet Simulator 99** passes: Auto Farm R$175; Lucky! (+200% egg luck) R$275; Auto Tap R$350; +15 Pets R$375; VIP R$400 (VIP area, a rewards chest every 6 hours, removes the mailbox tax); +15 Eggs R$625; Daycare Slots R$625; Ultra Lucky! (+500%) R$800; Magic Eggs R$1,200; +40 Egg Hatch R$1,499 (requires +15 Eggs); Super Shiny Hunter R$1,600; Super Drops R$2,400; Double Stars R$2,400; Huge Hunter (62.5x Huge chance, still not guaranteed) R$3,250. — [Pet Simulator Wiki](https://pet-simulator.fandom.com/wiki/Gamepasses_(Pet_Simulator_99))
- **Blox Fruits** passes: Fast Boats R$350; 2x Boss Drop Chance R$350; +1 Fruit Storage R$400 (stackable); 2x Money R$450; 2x Mastery R$450; Dark Blade R$1,200; Fruit Notifier R$2,700. Buying every pass costs about R$5,500. Passes can also be traded. Fragment packs (dev products) cost R$75-R$1,499. — [Blox Fruits Wiki](https://blox-fruits.fandom.com/wiki/Shop)
- **Steal a Brainrot** passes: 2X Money R$199; VIP R$199 (0.5x money multiplier, tag, +10s base lock time); HD Admin R$1,999 (admin commands). Premium gear sold for Robux: Blackhole Slap R$199, Flying Carpet R$499, Laser Gun R$999, Ban Hammer R$1,499. Several of these let a paying player fling other players. — [Deltia's Gaming](https://deltiasgaming.com/roblox-steal-a-brainrot-all-gear-and-game-passes)
- **Grow a Garden** Season 1 Pass: Premium track R$749 on top of a free track, 50 levels. Skip one level R$49; skip the whole ladder R$1,699. Progress comes from 6 daily quests worth 250 XP each. The pass was scheduled to end November 1, 2025. Other dev products: Level Up Lollipop R$79, Silver Fertilizer R$129, Prime Crate R$179, Prime Seed Pack R$199, Egg Yolk Mat R$239, Grow All R$375. — [Sportskeeda](https://www.sportskeeda.com/roblox-news/grow-garden-season-1-pass-all-tier-rewards-premium-price)
- In Grow a Garden, Robux can speed up waiting, unlock perks, and steal other players' crops. Pets come from loot-box-style eggs, and co-owner DoBig Studios was criticized for adding excessive monetization. — [Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)
- **Adopt Me** "Pets Plus" subscription: $2.99/month in the US, 30 days per purchase. Benefits: VIP status and VIP rooms, two pets equipped at once, more Bucks per day, a daily streak that survives a few missed days, a monthly sticker pack, and a Golden Bone (with a small chance of a legendary pet). — [Sportskeeda](https://www.sportskeeda.com/roblox-news/adopt-me-pets-plus-subscription-benefits-content-price)

**Platform monetization tools (official docs)**
- **Game passes** are one-time purchases for permanent perks. **Developer products** are repeatable purchases (currency, potions). Other options: paid access (Robux or local currency), private servers (free or a monthly Robux fee), immersive ads (image and portal formats), and managed pricing (regional pricing plus price optimization). Roblox's guidance says to avoid pushy or urgent language with minors. `PolicyService` checks by location, age and platform whether a user can see subscriptions, commerce products, paid random items, trading and immersive ads. — [Roblox Creator Docs: Monetization](https://create.roblox.com/docs/en-us/production/monetization.md)
- **Subscriptions:** five local-currency tiers ($2.99, $4.99, $7.99, $9.99, $14.99) or any Robux price of at least R$49. Local-currency subscriptions pay 70% in month 1 and 100% after that. Robux subscriptions pay 70% every month. Each game can have up to 50 subscriptions. Benefits must be honored for the full term and can't be quietly revoked. Mutually exclusive tiers (Bronze/Silver/Gold) aren't supported. Robux subscriptions can be repriced once every 60 days, and price increases need 30 days' notice. Local-currency subscriptions aren't available in Indonesia, India, Japan and several other countries. — [Roblox Creator Docs: Subscriptions](https://create.roblox.com/docs/en-us/production/monetization/subscriptions.md)
- **Creator Rewards (replaced Engagement-Based Payouts, the old Premium Payouts, and the Creator Affiliate program; started July 24, 2025):** "Daily Engagement" pays R$5 for each active spender (someone who spent at least $9.99 in the past 60 days) who plays 10+ minutes in your game as one of their first 3 experiences that day. "Audience Expansion" pays a 35% share of a new or returning user's first $100 of purchases over 60 days. The payout is held for 60 days. — [Roblox Creator Docs: Creator Rewards](https://create.roblox.com/docs/creator-rewards.md)
- **Rewarded video ads:** closed beta announced July 24, 2025, then live for all ad-enabled users on Windows PC from August 26, 2025. At launch, a game needed 100K+ average DAU over 28 days and a Minimal or Mild maturity rating; Roblox said it planned to widen access. **Only users 13+ see these ads.** `GetAdAvailabilityNowAsync` hides the option for under-13s. Ads are optional, 6-30 seconds, and offered as an alternative to spending Robux. Roblox expected them to make up about 3% of creator earnings at first. — [DevForum: More Creators Can Now Use Rewarded Video Ads](https://devforum.roblox.com/t/more-creators-can-now-use-rewarded-video-ads/3838678); [Roblox newsroom: video ads and Google partnership (Apr 2025)](https://about.roblox.com/newsroom/2025/04/roblox-scales-video-ads-partners-with-google)
- **Private servers:** free or a monthly Robux fee. Changing the price cancels all active subscriptions. Roblox Plus subscribers get paid private servers at no cost, and creators earn up to R$100 per subscriber per month based on time spent in them. — [Roblox Creator Docs: Private Servers](https://create.roblox.com/docs/en-us/production/monetization/private-servers.md)
- From September 24 (2026, inferred from context), Roblox Plus is limited to 1 free paid private server per game, because some members had created thousands. Games that offer free private servers allow unlimited ones. — [PCGamesN](https://www.pcgamesn.com/roblox/plus-private-server-limit)
- **DevEx:** $0.0038 per Robux since September 5, 2025, up from the legacy $0.0035 (about +8.5%). The minimum cash-out is R$30,000 (= $114). Cash-outs are limited to one per month, and the earner must be 13+. A higher $0.0054 rate applies to pass, product, subscription and private-server spending by US players age-checked as 18+, in eligible games. — [Roblox Creator Docs: Developer Exchange](https://create.roblox.com/docs/de-de/production/monetization/developer-exchange); [DevForum on the 8.5% change](https://devforum.roblox.com/t/incorrect-devex-rate-percentage-update-85-claim-is-not-accurate-%F0%9F%A5%80%E2%98%A0%EF%B8%8F/3920224)
- The 18+ rate is a 42% increase for spending by age-checked US adults in eligible (R15-avatar) games, effective June 8, 2026. Roblox says US users aged 18-34 monetize about 50% higher than under-18s. — [Roblox Newsroom, Apr 2026](https://about.roblox.com/newsroom/2026/04/roblox-fuels-high-fidelity-games-over-18-players-increases-qualifying-devex-rate-42)
- **Platform context, Q2 2026:** 123M DAU (+10% YoY), bookings $1.557B (+8%, at the low end of guidance), and DevEx (creator earnings) $363M (+15%). Per-hour monetization fell among younger US/Canada users, which Roblox attributes to engagement shifting away from "high monetizing, 2025-vintage viral games." — [Roblox Q2 2026 shareholder letter (SEC 8-K)](https://www.sec.gov/Archives/edgar/data/0001315098/000162828026051059/ex991-robloxq22026earnin.htm)

### Inferences
- The standard pass ladder works out to: a cheap entry pass (R$175-R$275, e.g. auto-farm or a small luck boost), core passes at R$350-R$450 (2x currency, VIP, +slots, speed), mid passes at R$600-R$800 (big luck or slots), and one or two whale passes at R$1,200-R$3,250.
- A kid-safe idle auto-battler could sell: Auto-Battle/Auto-Collect (~R$150-R$199), 2x Gold (~R$199-R$399), +Unit/Golem Slots (~R$299-R$399, stackable), +Storage (~R$199-R$399), Faster Battle Speed (~R$249-R$349), and a cosmetic VIP (~R$199-R$399).
- For ages 9-15, prefer cosmetics, time-savers and capacity over direct power. Steal a Brainrot's paid fling and steal gear and Grow a Garden's crop stealing are griefing-for-pay patterns to avoid.
- Creator Rewards pays for 10+ minute sessions from returning spenders, so session length and returning players have direct revenue value. Rewarded ads won't reach under-13s, so they shouldn't be a core revenue line for a game aimed at 9-15.

### Gaps
- I couldn't verify game pass prices for Bee Swarm Simulator, Anime Defenders, Fisch, or most of Adopt Me (only Pets Plus), or prices for Steal a Brainrot developer products.
- I found no official Roblox documentation on the commerce/Shopping API (selling physical goods) or on the current gifting API for passes. The DevForum gifting thread I found is from 2020. Starter-pack prices were not verified.
- The base price of Roblox Plus was not found.

## Retention: login rewards, quests, notifications, battle passes, events, restocks

### Takeaway
The best-documented retention tools are daily quests feeding a season pass (Grow a Garden), weekly limited-time items you must be online to claim, and Roblox's opt-in experience notifications (13+ only, 1 per day per experience). Roblox explicitly bans false time pressure in notifications. Subscription streak protection (Adopt Me) is an example of a gentle, kid-friendly streak design.

### Cited Findings
- Grow a Garden's season pass is driven by 6 daily quests (harvest X, earn Sheckles, plant Y), 1,500 XP per day across 50 levels, with a free and a premium track. — [Sportskeeda](https://www.sportskeeda.com/roblox-news/grow-garden-season-1-pass-all-tier-rewards-premium-price)
- Grow a Garden releases exclusive items weekly that must be claimed while online. Seeds rotate in and out of stock. Two event teams were formed in July 2025 to keep up with weekly events. — [Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)
- Adopt Me's Pets Plus includes a daily streak that doesn't reset if you miss a few days. — [Sportskeeda](https://www.sportskeeda.com/roblox-news/adopt-me-pets-plus-subscription-benefits-content-price)
- Pet Simulator 99's VIP pass gives a rewards chest every 6 hours, an example of a timed return gift. — [Pet Simulator Wiki](https://pet-simulator.fandom.com/wiki/Gamepasses_(Pet_Simulator_99))
- **Experience notifications** go only to opted-in users 13+. Under-13s get only experience updates. A game can send at most 1 per user per day, plus there's a cross-experience cap. `PromptOptIn()` won't show to under-13s or more than once every 30 days. Notifications should be personalized and actionable. Roblox prohibits disguised ads, false time pressure, misleading free-reward offers, and making notifications a requirement to progress. The game needs 100+ visits to use them. CTR analytics are available. — [Roblox Creator Docs: Experience Notifications](https://create.roblox.com/docs/production/promotion/experience-notifications.md)
- Subscription rules forbid adding extra tasks to unlock paid benefits, but battle passes are exempt from that rule. — [Roblox Creator Docs: Subscriptions](https://create.roblox.com/docs/en-us/production/monetization/subscriptions.md)
- Roblox's April 2026 discovery changes add long-term retention signals to recommendations and a "Standout Games" section for novel games. — [Roblox Newsroom, Apr 2026](https://about.roblox.com/newsroom/2026/04/roblox-fuels-high-fidelity-games-over-18-players-increases-qualifying-devex-rate-42)

### Inferences
- For an idle auto-battler, offline progress plus a daily quest list plus a free season track covers the core loop. Keep the premium track optional, with no level-skip upsells aimed at kids.
- Much of a 9-15 audience is under 13 and can't receive personalized notifications, so in-game hooks matter more than push. These include a weekly update countdown shown in the lobby, which is fine if it isn't tied to a purchase.

### Gaps
- I didn't verify specific daily-login reward tables, group-join reward implementations, favorite/like prompt norms, Grow a Garden weather and mutation mechanics, or restock timer intervals (e.g. 5-minute seed shop restocks) from a reliable source.

## Social/co-op: trading, servers, chat, social moments

### Takeaway
Trading drives value in Pet Sim, Blox Fruits and Grow a Garden. It also feeds real-money trading and scams, and Roblox requires a `PolicyService` check (`IsPaidItemTradingAllowed`) before allowing trades of paid items. Since late 2025/January 2026, chat has required a facial age check and is split into age bands. Social features for a 9-15 audience should work without chat. The biggest social moments came from live "admin abuse" events.

### Cited Findings
- Rare Grow a Garden items are sold for real money on eBay and Discord, which breaks Roblox's terms of service. — [Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)
- Grow a Garden shipped a dedicated Trading Update (patch notes dated August 2, 2025) with trade tickets. I couldn't retrieve the full details. — [Deltia's Gaming (metadata only)](https://deltiasgaming.com/?p=304155)
- Blox Fruits game passes can be traded, and a traded pass is redeemed on receipt. — [Blox Fruits Wiki](https://blox-fruits.fandom.com/wiki/Shop)
- `PolicyService:GetPolicyInfoForPlayerAsync()` returns `IsPaidItemTradingAllowed`. If it's false, the user can't trade outcomes of paid random items or other paid items. — [Roblox Creator Docs: Paid Random Items](https://create.roblox.com/docs/production/monetization/paid-random-items)
- **Age checks and chat (announced November 19, 2025):** chat requires facial age estimation (or ID for 13+). Enforcement started in AU, NZ and NL in early December 2025 and went global in early January 2026. Users are grouped as under 9, 9-12, 13-15, 16-17, 18-20 and 21+, and chat only with similar ages. Experience chat is off by default for under-9s unless a parent consents. Since early 2026, creators can't post social media links inside experiences. — [Roblox Newsroom, Nov 2025](https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat)
- As of Q2 2026, 57% of global DAU had age-checked, on-platform communication had not recovered to pre-check levels, and "Kids and Select accounts" launched in June 2026 with about 30,000 games. — [Roblox Q2 2026 letter](https://www.sec.gov/Archives/edgar/data/0001315098/000162828026051059/ex991-robloxq22026earnin.htm)
- **Admin Abuse War (August 2025):** Grow a Garden (22.3M CCU) and Steal a Brainrot (20.1M) ran rival live admin events, which pushed Roblox to a record 47.29M concurrent players and briefly crashed the platform. — [Lenovo Legion Gaming](https://gaming.lenovo.com/roblox/post/roblox-just-shattered-the-all-time-record-for-concurrent-players-8s7u0nswtSVrLpi); [Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)
- Private servers can be free or paid monthly. Roblox Plus gives one free paid private server per game, or unlimited where the creator makes them free. — [Roblox Creator Docs: Private Servers](https://create.roblox.com/docs/en-us/production/monetization/private-servers.md); [PCGamesN](https://www.pcgamesn.com/roblox/plus-private-server-limit)

### Inferences
- For a kid-safe auto-battler: co-op raids or boss fights with friend bonuses (e.g. +X% while in a party with friends), emote and ping communication that works without chat, and scheduled global events such as a world boss. Skip open trading, or limit it to non-paid items behind a two-sided confirmation and a value-warning screen, and check `IsPaidItemTradingAllowed`.
- Free private servers are an easy goodwill win and also lift Roblox Plus engagement payouts.

### Gaps
- I couldn't verify server size norms, specific trade safeguards (trade confirmation timers, value warnings) from the top games, friend-invite reward implementations, or voice chat policy details.

## Live ops: update cadence, codes, collabs, CCU impact

### Takeaway
Grow a Garden's weekly updates (on weekends) set CCU records step by step, from about 5M (May 18, 2025) to 22.3M (August 23, 2025). CCU spikes on update day and falls sharply within hours. In Q2 2026 Roblox reported that the 2025 viral hits were declining and the market was spreading out beyond the top games.

### Cited Findings
- Grow a Garden CCU by update: Blood Moon (May 18, 2025) about 5M; Bizzy Bees (May 31) 11.7M+; Working Bees (June 14) 16M+, above Fortnite's 15.3M record; Summer Update (June 21) 21.3M (sources conflict, some say 16M); August 23 at least 22.3M. After the June 21 peak, CCU fell to 7.6M within an hour, and the average on June 25 was 2.7M. Steal a Brainrot passed it with 24M in September 2025. Grow a Garden doesn't disclose revenue. — [Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)
- Insider Gaming reported that Grow a Garden broke its own all-time record two weeks in a row (June 2025). — [Insider Gaming](https://insider-gaming.com/roblox-grow-a-garden-shatters-all-time-player-record-for-second-week-in-a-row/)
- Analyst TD Cowen raised concerns about bot activity in Grow a Garden's surge, then retracted the manipulation claim. Roblox disputed the concerns. — [Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)
- Q2 2026: new hits Animal Hospital, Grow a Garden 2 and Kick a Lucky Block rose quickly. The top 10 games now take about 20% of hours, down from 30% three years ago. — [Roblox Q2 2026 letter](https://www.sec.gov/Archives/edgar/data/0001315098/000162828026051059/ex991-robloxq22026earnin.htm)
- Since early 2026, creators can't share social media links inside experiences, so codes can't be promoted by sending players to Discord or X from inside the game. — [Roblox Newsroom, Nov 2025](https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat)

### Inferences
- A weekly update at a fixed day and time, with an in-game countdown, concentrates CCU, which helps discovery ranking. The fast drop-off means each update needs content that brings players back every day (quests, events), not just a single spike.
- Discord and X are 13+ platforms, and creators can no longer link to social media inside experiences. Put codes in the in-game update log or announcement board instead.

### Gaps
- I didn't verify the exact weekday or time of Grow a Garden's updates (commonly said to be Saturday), Steal a Brainrot's admin abuse schedule, how code distribution works in practice, or specific brand collaborations.

## Dark patterns for kids and Roblox rules (cross-cutting)

### Cited Findings
- **Paid random items** include egg hatches, wheel spins, chests, random-duration potions, combining items, and **luck boosts and pity systems** (probability modifiers). Paid ones need full odds shown as percentages before purchase. A bare (i) icon isn't enough, and odds must update for one-time outcomes. Where `ArePaidRandomItemsRestricted` is true, a game must offer a free earning path, a disclosed fixed order, direct purchase at expected-value pricing, or block or hide the item. Random rewards earned only through gameplay need no disclosure. — [Roblox Creator Docs: Paid Random Items](https://create.roblox.com/docs/production/monetization/paid-random-items)
- Korean loot box rules pushed Roblox to require odds disclosure worldwide (June 2026 report). — [Tech Times](https://www.techtimes.com/articles/319148/20260626/koreas-loot-box-rules-push-roblox-disclose-item-odds-worldwide.htm)
- Roblox's monetization guidance tells creators to avoid pushy or urgent language with minors. — [Roblox Creator Docs: Monetization](https://create.roblox.com/docs/en-us/production/monetization.md)
- Notifications can't use false time pressure, misleading free-reward offers or disguised ads. — [Roblox Creator Docs: Experience Notifications](https://create.roblox.com/docs/production/promotion/experience-notifications.md)
- Patterns in the top games that are risky for kids: pets from loot-box eggs and accusations of excessive monetization (Grow a Garden) ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)); paid Robux luck multipliers stacking up to "Huge Hunter" at R$3,250 for a non-guaranteed chance (Pet Sim 99) ([Pet Simulator Wiki](https://pet-simulator.fandom.com/wiki/Gamepasses_(Pet_Simulator_99))); paid gear to fling other players and paid admin commands (Steal a Brainrot) ([Deltia's Gaming](https://deltiasgaming.com/roblox-steal-a-brainrot-all-gear-and-game-passes)); level-skip upsells such as R$1,699 to skip a whole season pass ([Sportskeeda](https://www.sportskeeda.com/roblox-news/grow-garden-season-1-pass-all-tier-rewards-premium-price)).

### Inferences
- Safest approach for a 9-15 game: don't sell random items for Robux (sell items directly), keep luck boosts off the Robux store or treat them under the full paid-random-items rules, show event countdowns but never attach a limited-time purchase prompt to them, and use no PvP pay-to-win or griefing-for-pay.

### Gaps
- I found no verified source on Roblox enforcement actions against specific top games for dark patterns.
