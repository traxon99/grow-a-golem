# Grow A Golem roadmap

This file is the shared to-do list for everyone working on the game, people and Claude sessions alike. **Read it before you start any work, and claim your row first.**

Last reviewed: 2026-10-27, after PR #29.

## Where the project stands

The game is written but has never been played. All 44 Luau files compile and pass the offline tests in CI, but none of the code has run in Roblox Studio or a published place. So Phase 1 (play it and fix what breaks) comes before everything else.

Three issues are open: [#9](https://github.com/traxon99/grow-a-golem/issues/9) (playtest and pacing), [#15](https://github.com/traxon99/grow-a-golem/issues/15) (content and balance) and [#16](https://github.com/traxon99/grow-a-golem/issues/16) (art and launch). Details live in [`docs/playtest.md`](docs/playtest.md), [`docs/expansion-design.md`](docs/expansion-design.md) and [`docs/launch/plan.md`](docs/launch/plan.md).

## How to use this roadmap

Every task is a row with an ID (like `R1.3`) and a **Status**. There are four statuses:

| Status | Meaning |
| --- | --- |
| `Open` | Nobody is on it. You may claim it. |
| `In progress: <who>, <branch>, <date>` | Someone is on it. Don't work on it, and don't edit the files (or parts of files) in its **Touches** column. |
| `Done: #<PR>` | Merged into `main`. |
| `Waiting: <reason>` | Can't start yet, for the reason given. |

### Before you start

1. Pull the latest `main` and read this file.
2. Pick an `Open` row. Skip every row that is `In progress`, and stay out of the files in its **Touches** column. If you must change one of those files, comment on the row's issue and ask the person who claimed it first.
3. **Claim the row.** Change its status to `In progress: <who>, <branch>, <today's date>`. For a Claude session, `<who>` is `Claude for @<GitHub login of the person running it>`. Commit only that change, with the message `roadmap: claim R1.3`, and push it **straight to `main`** so everyone sees it at once:

   ```sh
   git pull --rebase origin main
   # edit the Status cell of your row
   git add ROADMAP.md
   git commit -m "roadmap: claim R1.3"
   git push origin main
   ```

   If the push is rejected, run `git pull --rebase origin main` and look at your row again. A rebase conflict on that row means someone claimed it first: abort the rebase (`git rebase --abort`), reset to `origin/main` and pick another row.
4. Comment on the row's GitHub issue that you're starting, and assign yourself if you can.
5. Branch off `main` (after the claim commit) and do the work.

### When you finish

- In the **same PR** that does the work, change the row's status to `Done: #<PR number>`. The row flips to done when the PR merges, not before.
- If the work turned up new tasks, add them as new `Open` rows in the same PR.

### If you stop

- Set the row back to `Open` and push that straight to `main`, with a one-line note on the issue about where you left the branch.
- A claim with no new commits on its branch for 7 days is stale. Ask on the issue; if nobody answers within 2 days, anyone may set it back to `Open`.

### Adding work

- New task: add a row to the right phase with the next free ID and status `Open`, then claim it as above. Never reuse or renumber IDs, since other notes point at them.
- Bug found while testing: add it to [Found in testing](#found-in-testing), not to a phase.

### The Needs column

- **Studio**: someone has to run the game in Roblox Studio. A cloud Claude session can't.
- **Owner**: needs the owner's Roblox account (traxon99), for example the Creator Dashboard, the Roblox group or ad spend.
- **Code**: can be done entirely in this repo, by a person or a Claude session.

## Phase 1: Make it run ([#9](https://github.com/traxon99/grow-a-golem/issues/9))

Gate: no errors in Output during a full solo run and a 3-player run, and progress survives leave and rejoin in a published place. The full test matrix is in [`docs/playtest.md`](docs/playtest.md).

| ID | Task | Needs | Touches | Status |
| --- | --- | --- | --- | --- |
| R1.1 | Solo pass from a fresh save through boss 6. Log each Output error as a row in Found in testing | Studio | its rows in `docs/playtest.md` | Open |
| R1.2 | Open every menu and press every button | Studio | its rows in `docs/playtest.md` | Open |
| R1.3 | Steering and spells on PC, gamepad and the phone emulator | Studio | its rows in `docs/playtest.md` | Open |
| R1.4 | 3-player test (Test → Clients and Servers): party invite and leave, shared kills, friend bonus, trading | Studio | its rows in `docs/playtest.md` | Open |
| R1.5 | Publish a private test place; run the seven save tests in `docs/playtest.md` with test accounts | Owner, Studio | its rows in `docs/playtest.md` | Open |
| R1.6 | README "Building your own islands" names only `Zone1` to `Zone3`; the code reads `Zone1` to `Zone6` | Code | `README.md` | Open |

## Phase 2: Tune pacing ([#9](https://github.com/traxon99/grow-a-golem/issues/9), [#15](https://github.com/traxon99/grow-a-golem/issues/15))

Starts after the Phase 1 gate. Gate: the timing sheet in `docs/playtest.md` meets its targets, or the targets are changed on purpose. Only one person should edit `Config.luau` balance numbers at a time.

| ID | Task | Needs | Touches | Status |
| --- | --- | --- | --- | --- |
| R2.1 | Three purchase-free timed runs; fill in the timing sheet | Studio | its rows in `docs/playtest.md` | Waiting: Phase 1 |
| R2.2 | Tune zones 1–3 until they hit their targets (first boss in 10–20 min, zone 2 under 25 min) | Code | `src/shared/Config.luau` | Waiting: R2.1 |
| R2.3 | Set targets for zones 4–6 from measured data, then tune them | Studio, Code | `src/shared/Config.luau`, `docs/playtest.md` | Waiting: R2.2 |
| R2.4 | With guardian consent, watch 2–3 testers aged 9–15 play for 15 min without hints; note where they stall | Studio | its rows in `docs/playtest.md` | Waiting: Phase 1 |
| R2.5 | Fix the onboarding problems R2.4 finds | Code | `TutorialService`, `src/client/Tutorial.luau`, `Config.Tutorial` | Waiting: R2.4 |

## Phase 3: Launch prep ([#16](https://github.com/traxon99/grow-a-golem/issues/16))

Owner rows can start now. Gate: the owner signs off on the store page and the published build. The checklist is in [`docs/launch/plan.md`](docs/launch/plan.md).

| ID | Task | Needs | Touches | Status |
| --- | --- | --- | --- | --- |
| R3.1 | Create the 15 store items (5 game passes, 5 developer products, 5 paid cosmetics) and paste their ids into `Config` | Owner | `Config.GamePasses`, `Config.Products`, `Config.Cosmetics` | Open |
| R3.2 | Create the Roblox group; set `Config.Group.id` | Owner | `Config.Group` | Open |
| R3.3 | Upload the 19 WAVs in `assets/audio`, grant permissions, set the sound ids | Owner | `Config.Sounds`, `Config.SoundEffects` | Open |
| R3.4 | Review the model templates in Studio; replace weak pieces | Studio | `assets/models`, `scripts/create_assets.py` | Waiting: Phase 1 |
| R3.5 | Capture real gameplay for the icon and at least 3 thumbnails | Studio | `assets/keyart`, `docs/launch/game-page.md` | Waiting: Phase 2 |
| R3.6 | Publish the store description once it matches the build | Owner | `docs/launch/game-page.md` | Waiting: R3.5 |
| R3.7 | Check analytics events appear in the Creator Dashboard | Owner | none | Waiting: R1.5 |
| R3.8 | Release plan: shut down servers running the version without save leases before going live | Owner | `docs/playtest.md` | Open |

## Phase 4: Soft launch

Starts after the Phase 3 gate. Gate (from `docs/launch/plan.md`; the team's own thresholds): at least half of new players finish the tutorial, D1 retention is 15% or more, and median session is 8 minutes or more. Below that, fix the game before spending more.

| ID | Task | Needs | Touches | Status |
| --- | --- | --- | --- | --- |
| R4.1 | Make the game public | Owner | none | Waiting: Phase 3 |
| R4.2 | Run the Sponsored ad test, capped at US$50, only with the owner's approval | Owner | `docs/launch/plan.md` | Waiting: R4.1 |
| R4.3 | Weekly review of retention, onboarding and shop funnels; file what they show as new rows | Owner | none | Waiting: R4.1 |

## Phase 5: Grow

Code rows can start any time, but Phase 1 fixes come first, and building on untested code risks rework.

| ID | Task | Needs | Touches | Status |
| --- | --- | --- | --- | --- |
| R5.1 | Build the co-op tower from `docs/expansion-design.md` | Code, Studio | new service, `PartyService`, `WorldService`, `Menus.luau`, `Config.luau` | Open |
| R5.2 | Make trades crash-safe across both players' saves | Code, Studio | `TradeService`, `DataService` | Open |
| R5.3 | Give zones 4–6 their own scenery and atmosphere | Code | `src/server/Models/Islands.luau`, `WorldService` | Open |
| R5.4 | Measure the full path toward the 20-hour goal; plan content per update from the data | Studio | `docs/expansion-design.md` | Waiting: Phase 2 |
| R5.5 | Decide whether to move saves to ProfileStore | Code | `DataService` | Open |

## Found in testing

Bugs and problems found while working through the phases. Give each a `B` number in order.

| ID | Problem | Found by | Touches | Status |
| --- | --- | --- | --- | --- |
| | None yet | | | |
