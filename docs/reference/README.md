# Grow A Golem design reference library

Last updated: 2026-10-27. Research access date for all sources: 2026-10.

## Purpose

This folder records what the most popular Roblox games (simulators, idle, tycoons, pet collectors, RPGs) do across UI/UX, loops, progression, monetization, retention, onboarding, social, live ops, art/audio, performance/mobile, and safety/compliance for a 9-15 audience. It also records how Grow A Golem compares today. It is written for AI coding agents and for Jackson (the developer) working on this Roblox Luau/Rojo project.

## How agents should use this library

1. **Before you design or change a system, read the doc for that system.** Changing the shop? Read `monetization.md` and `safety-compliance.md`. Changing the HUD? Read `ui-ux.md` and `performance-mobile.md`.
2. **`safety-compliance.md` overrides everything else.** If any other doc, a top game's example, or a backlog issue conflicts with it, the safety doc wins. Do not ship a pattern because a top game does it.
3. Follow the "Rules for agents" section of each doc first. These are concrete and testable. The "What top games do" section is context, not a mandate.
4. Treat any claim marked "(unverified)", "(inference)", "(common practice, unverified)" or "(low confidence)" as a hypothesis. Do not quote it to players or as a requirement.
5. Numbers about other games (prices, CCU, timers) change often. Check the date stamp before relying on one.

## Documents

| Doc | What it covers |
|---|---|
| [safety-compliance.md](safety-compliance.md) | **Overrides all others.** Paid random items, odds, PolicyService, text filtering, maturity labels, ads, codes, kid-safe rules. |
| [ui-ux.md](ui-ux.md) | HUD layout, safe insets, touch reach, text scaling, accessibility, number formatting. |
| [gameplay-loops.md](gameplay-loops.md) | 30-second / 5-minute / session loops in top games and how ours maps. |
| [progression.md](progression.md) | Rebirth, zone gating, rarity ladders, collection books, XP curves. |
| [monetization.md](monetization.md) | Game pass and product norms, price ladders, platform programs (Creator Rewards, subscriptions, DevEx). |
| [retention.md](retention.md) | Daily/weekly quests, login streaks, offline gains, season passes, notifications, benchmarks. |
| [onboarding.md](onboarding.md) | First-time user experience, time-to-fun, funnel events, D1 benchmarks. |
| [social.md](social.md) | Co-op, trading, chat and age checks, private servers, live social moments. |
| [live-ops.md](live-ops.md) | Update cadence, events, codes, CCU behavior around updates. |
| [art-audio.md](art-audio.md) | Visual style, lighting, juice, rarity colors, audio permissions, thumbnails. |
| [performance-mobile.md](performance-mobile.md) | Mobile share, frame budget, draw calls, streaming, remote traffic. |
| [visual-references.md](visual-references.md) | Links to pages showing notable game UIs, plus our own wireframes. |
| [research-notes/](research-notes/) | Raw cited research notes the docs were written from (Takeaway, Findings, Inferences, Gaps). Check here before re-researching a topic. |

## How to add or update a doc

- **Cite every fact with a URL** inline, and list it in the doc's "Sources" section with an access month (e.g. "accessed 2026-10").
- **Date-stamp facts that change** (prices, CCU, policy dates): write "as of 2026-10" or the event date.
- **Summarize in your own words.** No long quotes; a few words in quotation marks is the maximum.
- **Mark unverified claims** with "(unverified)", "(inference)" or "(common practice, unverified)". Never upgrade a guess to a fact because it sounds right.
- **Keep the "Grow A Golem today" section current.** When you change code that a doc describes (Config.luau values, UI layout, monetization, safety checks), update that section in the same change.
- Keep the topic-doc structure: Rules for agents, What top games do, Grow A Golem today, Gaps worth closing, Sources.
- Keep each doc focused (about 80-200 lines). Split a doc rather than letting it sprawl.
- If a new finding conflicts with `safety-compliance.md`, update the safety doc first and get Jackson's sign-off.

## About visuals

Screenshots of other games are **not stored here** (copyright, and they go stale). Visual references are links to the source pages in [visual-references.md](visual-references.md), plus our own original wireframes in `docs/reference/images/`.

## Backlog issues referenced in these docs

- #9 playtest P0 (first Studio playtest)
- #11 analytics
- #12 codes and events
- #13 hub and trading
- #14 cosmetics/pets, direct purchase only
- #15 content depth
- #16 art and marketing
