# Grow A Golem: notes for agents

Read `README.md` for setup, the code layout and where each system lives.

## Design reference library

Before you design or change any player-facing system (UI, loops, progression, monetization, retention, onboarding, social, live ops, art, audio, performance, safety), read the matching doc in [`docs/reference/`](docs/reference/README.md). Start at its README.

- `docs/reference/safety-compliance.md` overrides everything else. The players are 9 to 15: show real odds before any paid random item (including luck boosts), keep pity timers, never fake a near-miss, sell cosmetics only by direct purchase, no purchase countdowns, and keep codes free.
- When your change alters something a doc describes, update that doc's "Grow A Golem today" section in the same PR.
- New research goes into the library with cited source URLs and a date, following the rules in `docs/reference/README.md`.

## Skills

- [`.claude/skills/auto-ship`](.claude/skills/auto-ship/SKILL.md): when anyone says "ship", "auto-ship <feature>" or "auto-ship #NN", take one change from GitHub issue to merged PR. It routes the work to the matching `docs/reference/` docs (always the safety doc), syntax-checks Luau with `luau-compile --null`, has a fresh subagent review the diff, and merges with a merge commit unless the repo requires a review. The caller is credited, assigned and asked any questions.
