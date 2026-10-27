# Performance and mobile

Last updated: 2026-10-27. See also [ui-ux.md](ui-ux.md) for touch layout and safe insets.

## Rules for agents

1. **Design for a phone first.** About 80% of Roblox DAU played on mobile in 2024 ([PocketGamer.biz](https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue)).
2. **Pick one low-end baseline phone and test on it throughout;** Studio's emulator misreports memory ([Design for performance](https://create.roblox.com/docs/en-us/performance-optimization/design)).
3. **Budget: 16.67 ms per frame (60 FPS);** baseline example under 1,000 draw calls and under 1,000,000 triangles. Check with Shift+F2 render stats and the F9 Developer Console (same source).
4. **Spread heavy work:** never do more than a few ms in one frame; split into slices (same source: 100 ms in one frame caps the game at 10 FPS).
5. **Event-driven over per-frame loops;** disconnect connections you no longer need (same source).
6. **Keep client-unneeded assets in ServerStorage,** not ReplicatedStorage (the client loads all of ReplicatedStorage) (same source).
7. **Prefer built-in materials over custom textures,** reuse meshes and textures, keep Transparency at 0 or 1 to avoid overdraw (same source).
8. **Enable instance streaming** unless a measured reason says otherwise; Roblox recommends it for most places (same source).
9. **Batch combat traffic:** simulate on the server in ticks and send compact state a few times per second, not one remote per hit; render hit effects client-side (inference). Stay well under about 20 fires/s per remote (community claim, unverified, [DevForum](https://devforum.roblox.com/t/remote-event-limitations/3882204)).
10. **Cap particles, debris and damage numbers** with a pool and a per-device limit (inference).
11. **Validate every client intent on the server** (rate and range), since the client only sends intents.

## What top games do / what Roblox documents

- **Mobile share:** about 80% of 82.9M average DAU in 2024 played on mobile; mobile app stores were 46% of Robux revenue ([PocketGamer.biz](https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue)). GameAnalytics sees PC+mobile at about half of players and console about 2% in its tracked games ([GameAnalytics 2025](https://investgame.net/wp-content/uploads/2025/09/2025-Roblox-Benchmark-Report.pdf)).
- **Platform scale 2025:** 126.5M average DAU, 123.8B hours ([Newzoo via GameDevReports](https://gamedevreports.substack.com/p/newzoo-top-roblox-games-in-2025)).
- **Design for performance** ([Roblox Docs](https://create.roblox.com/docs/en-us/performance-optimization/design)):
  - 16.67 ms frame; low-end example under 1,000 draw calls and 1M triangles.
  - Streaming improves join times, memory and frame rate.
  - Built-in materials use far less memory than custom textures; packages help reuse.
  - Tools: F9 Developer Console (memory), Shift+F2 (draw calls, triangles).
- **Remote limits (community, no staff source):** about 20 fires/s per remote is "relatively safe"; a 15 calls/s limit is disputed; `UnreliableRemoteEvent` payload has a cap (stated as 1000 KB, may be bytes; verify) ([DevForum](https://devforum.roblox.com/t/remote-event-limitations/3882204)).
- **Not found:** official per-device memory budgets, part or instance count targets, a remote bandwidth cap (the often-quoted ~50 KB/s is unsourced), MicroProfiler guidance. MeshParts beating complex unions is DevForum consensus, unverified.
- **Session context:** the 25th-percentile session fell to about 2 min in 2025; performance problems on join cost players before they reach the loop ([GameAnalytics 2025](https://investgame.net/wp-content/uploads/2025/09/2025-Roblox-Benchmark-Report.pdf)).

## Grow A Golem today

- Server-authoritative; client sends intents only.
- Optional original part-based templates in `ReplicatedStorage.Assets` supplement procedural fallbacks (not MeshParts); procedural Motor6D animation; low-poly; built-in materials (e.g. DiamondPlate on iron tier). Part count per golem and per enemy not measured.
- Hit flashes, damage numbers and debris: pooling and caps not confirmed.
- `StreamingEnabled` not found in `default.project.json` (check the place file in Studio).
- Lighting set from `WorldService`; Technology not set in code.
- The eight-tier/six-boss/prop library replicates from ReplicatedStorage as required by #16. Its phone memory/instance cost still needs measurement; prune unused art or move server-only templates if this budget proves too high.
- Not yet run on a phone (#9); no frame, draw call or memory numbers recorded.

## Gaps worth closing

1. **P0 (#9):** Run on one low-end phone; record FPS, draw calls, triangles and client memory in this doc for each zone and during a boss fight with a 4-player party.
2. **P0 (#9):** Count remote fires per second during combat; batch if any remote fires per hit.
3. **P1:** Decide on StreamingEnabled and set it explicitly in the project file; test that zones load before players arrive.
4. **P1:** Pool and cap damage numbers, debris and particles; lower the cap on touch devices.
5. **P2:** If part counts are high, convert repeated golem and enemy parts to shared MeshParts (#16).
6. **P2:** Move anything only the server needs out of ReplicatedStorage.

## Sources

All accessed 2026-10.
- PocketGamer.biz, 80% of Roblox users on mobile: https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue
- Roblox Creator Docs, Design for performance: https://create.roblox.com/docs/en-us/performance-optimization/design
- Roblox Creator Docs, Performance optimization hub (not fetched): https://create.roblox.com/docs/performance-optimization
- DevForum, Remote event limitations: https://devforum.roblox.com/t/remote-event-limitations/3882204
- DevForum, real-world building and scripting optimization (not fetched): https://devforum.roblox.com/t/3127146
- GameAnalytics 2025 Roblox Benchmark Report: https://investgame.net/wp-content/uploads/2025/09/2025-Roblox-Benchmark-Report.pdf
- Newzoo via GameDevReports, top Roblox games 2025: https://gamedevreports.substack.com/p/newzoo-top-roblox-games-in-2025
