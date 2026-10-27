---
name: auto-ship
description: End-to-end delivery of one Grow A Golem change, tracked through a GitHub issue. Find or create the issue (checking for duplicates first), sort the work into categories and read the matching docs in docs/reference/ (always including safety-compliance.md), implement it in Luau, syntax-check it, have a fresh subagent review the diff against those docs, update the docs' "Grow A Golem today" sections, open a PR that closes the issue, and merge it. Use this when Jackson asks to "ship", "auto-ship", "just get this done", "build and merge", or says "auto-ship <feature>" or "auto-ship #NN". Don't use it for exploration, questions, or anything Jackson wants to review before it lands.
---

# Auto-ship

Grow A Golem is Jackson's single-maintainer Roblox game (Luau, synced into Studio with Rojo). Jackson's standing rule is that Claude merges its own PRs on `traxon99/grow-a-golem` without waiting for review. That trust covers the branch and PR this run creates. It does not cover other branches, other people's PRs, or repo settings.

Every run is tracked through exactly one GitHub issue, from before the first line of code to the merge. The issue records what was asked and what happened.

Don't skip the doc routing, syntax check, review or documentation steps to get to the merge faster. The players are 9 to 15, so a fast merge that breaks a safety rule isn't a win.

## 1. Find or create the tracking issue

Work out the feature from the request ("auto-ship trading" means trading; "auto-ship #13" means issue 13; a bare "ship this" means the fuller description earlier in the conversation).

- **An issue number was given.** Confirm it exists and is open with `issue_read`.
- **Otherwise, search first.** Run `list_issues` (open first) or `search_issues` on `traxon99/grow-a-golem` with keywords from the request. The backlog of gaps against top Roblox games lives here with `priority: P0`/`P1`/`P2` labels, so a matching issue often exists already.
  - A clear open match: use it.
  - The best match is closed as completed: the feature probably shipped. Say so and ask Jackson before redoing it.
  - Several plausible matches: ask if it's genuinely ambiguous, otherwise create a new issue.
- **No match.** Create one with `issue_write` (`method: create`): a title from the request and a short body saying what was asked and by whom.

Comment on the issue that auto-ship is picking it up. If `list_issue_fields` shows a project `Status` field, move the issue to In Progress instead of commenting. Re-check that each run.

## 2. Route the work to the reference docs

Sort the change into one or more categories, then read the "Rules for agents" section of each matching doc in `docs/reference/` and the "Grow A Golem today" section for the systems you'll touch. **Always read `safety-compliance.md` in full, whatever the category.** It overrides every other doc, every top game's example, and the issue itself.

| Category | Typical signs in the request or diff | Read | Code usually lives in |
|---|---|---|---|
| UI / HUD / menus | buttons, panels, HUD, text, layout, controls | `ui-ux.md`, `performance-mobile.md` | `src/client/Hud.luau`, `Menus.luau`, `Ui.luau`, `Controls.luau` |
| Gameplay loops | combat, mining, riding, bosses, enemies, islands | `gameplay-loops.md` | `GolemService`, `CombatService`, `MiningService`, `EnemyService`, `WorldService` |
| Progression | forging, levels, skill tree, awakening (rebirth), artifacts, zones, balance numbers | `progression.md` | `ProgressionService`, `ArtifactService`, `src/shared/Stats.luau`, `Config.luau` |
| Monetization | game passes, products, prices, shop, luck boosts, paid cosmetics | `monetization.md` (and the paid-random rules in the safety doc) | `PassService`, `CosmeticService`, `Config.GamePasses`, `Config.Products` |
| Retention | daily login, quests, streaks, offline gains, gifts, notifications | `retention.md` | `RewardService` |
| Onboarding | tutorial, first session, time to fun, funnel steps | `onboarding.md` | `TutorialService`, `src/client/Tutorial.luau`, `Config.Tutorial` |
| Social | parties, co-op, friends, trading, hub, chat, leaderboards | `social.md` | `PartyService`, `LeaderboardService` |
| Live ops | codes, events, update cadence, banners | `live-ops.md` | `CodeService`, `LiveEventService`, `Config.Codes`, `Config.Events` |
| Art / audio | models, lighting, effects, animation, sounds, thumbnails | `art-audio.md`, `visual-references.md` | `src/server/Models/`, `src/client/Fx.luau`, `Animator.luau`, `Sfx.luau` |
| Performance / mobile | frame rate, remotes, streaming, part counts, touch | `performance-mobile.md` | anywhere; `src/shared/Remotes.luau` for network traffic |
| Safety | odds, pity, chat, text filtering, PolicyService, age checks, codes | `safety-compliance.md` | wherever the feature is |

Most changes hit two or three rows (a new shop item is monetization, UI and safety). Note the routed docs; the review in step 5 checks against exactly this list. Check `docs/reference/research-notes/` before doing new research. If you do research, add it to the library with cited URLs and a date, following `docs/reference/README.md`.

**Stop and ask Jackson** before building anything that conflicts with `safety-compliance.md`, and before changing the safety doc's rules (its README says that needs Jackson's sign-off). Keep building any part that doesn't depend on the answer. Hard lines that never need asking about: real odds shown before any paid random item (luck boosts included), pity timers kept, no faked near-misses, cosmetics sold only by direct purchase, no purchase countdowns, codes stay free.

## 3. Branch

Use the session's designated branch (the "Git Development Branch Requirements" section names it). If that branch's earlier PR is already merged, restart it from `main` (`git fetch origin main && git checkout -B <branch> origin/main`). Otherwise branch off `main` with a short descriptive name.

## 4. Implement

Read `README.md` for where each system lives, then follow the patterns already in the surrounding code:

- Every balance number and piece of content (zones, enemies, artifacts, skills, quests, prices, codes, events, cosmetics) goes in `src/shared/Config.luau`, not inline in a service.
- Server logic is a service under `src/server/Services/`; the client never decides rewards, purchases or damage. New client-server traffic goes through `src/shared/Remotes.luau`, and the server validates every remote's arguments.
- Models are built in code with Motor6D joints tagged with a `Kind` attribute, and `src/client/Animator.luau` animates them. Maps and art Jackson builds in Studio stay out of the repo.
- Paid items keep `id = 0` until Jackson creates them in the Creator Dashboard; the Shop shows "Coming soon" for those.
- Keep the diff to what the issue asks for.

## 5. Verify, then review

**Syntax-check every changed `.luau` file.** Download the official Luau release into your scratchpad (`https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip`), unzip it, and run `luau-compile --null <file>` on each changed file. That catches parse errors only; a full type check isn't available in the cloud sandbox. If the download or run is refused, say so in the PR body and read the changed code once more by hand instead.

Studio can't run here, so nothing executes the game before merge. Write numbered playtest steps for Jackson (what to do in Studio, what they should see, what to look for in the Output window) for the PR body and the final message.

**Then review the diff in a fresh agent.** Spawn one `general-purpose` subagent with this prompt, filling in the doc list and issue number:

> You are reviewing a diff for the grow-a-golem Roblox repo before it merges. Run `git diff origin/main...HEAD`. Read `docs/reference/safety-compliance.md` in full and the "Rules for agents" section of each of these docs: <routed docs>. For each rule that applies to the diff, decide whether the diff follows it. Also check that balance numbers live in `src/shared/Config.luau`, that the server validates every new remote, and that the diff does what issue #NN asked for. Report only real violations, each with file and line, the rule it breaks, and the fix. Reply "No findings" if there are none. Don't edit files.

The review is done when every finding is fixed in the branch or answered in the PR body under "Reference docs check" with why it doesn't apply. Re-run the syntax check after fixes.

## 6. Update the docs

In the same branch:

- Update the "Grow A Golem today" section of every routed doc whose described behavior changed, and tick off or edit any "Gaps worth closing" line this run closes.
- Update the systems table in `README.md` if a system or its location changed, and any setup steps (new pass or product ids to create, new codes).
- Update project memory if this run settles a fact a later thread would otherwise have to ask Jackson again.

## 7. Open the PR

Commit with a clear message and push with `git push -u origin <branch>`. Check for a PR template and fill it if there is one. Otherwise structure the body as:

- the two-line PR attribution block from the session context, as the first two lines
- **Summary**: what changed and why, in a few sentences
- **Reference docs check**: the categories and docs this run routed to, and how the change follows the safety doc
- **Verification**: which files passed `luau-compile --null`, and the review result
- **Playtest in Studio**: the numbered steps from step 5
- `Fixes #NN`

The closing keyword links the PR in the issue's Development panel and closes the issue when the PR merges. Then assign Jackson and request their review (`issue_write` with `assignees: ["traxon99"]`, `update_pull_request` with `reviewers: ["traxon99"]`), and comment on the issue with the PR link.

## 8. Merge

Subscribe to the PR's activity. The harness's PR-driving rules cover conflicts, red CI and review findings; follow those.

- The repo has no CI yet, so once the PR is open and has no merge conflict, merge it straight away. If CI checks exist by the time you run this, wait for them to pass first.
- Merge with **`merge_method: "merge"`** (a merge commit), the convention in this repo's history. Never squash: after a squash merge the designated branch can't be reset to `main` without a force push.
- Don't delete the designated branch; later threads reuse branch names.
- A required human approval from branch protection is a real wall. If the merge is refused for that, say so and stop.
- Never get to a merge by skipping a check, weakening a safety rule, or force-pushing past a conflict.

After the merge, confirm the issue closed with `issue_read`. If the project has a `Status` field, set it to Done.

## When you're done

Tell Jackson in one short message: what merged, the issue and PR (numbers and links), that the issue closed with the merge, and the playtest steps to try in Studio. If something blocked the loop (a safety conflict, a required review, an ambiguous design choice), say exactly what's blocking and where the branch and issue were left.
