# Grow A Golem: notes for agents

Read `README.md` for setup, the code layout and where each system lives.

## Roadmap: check it and claim before you start

More than one person, and more than one Claude session, works on this repo at once. [`ROADMAP.md`](ROADMAP.md) is the shared list of what's open, in progress and done.

- Before any work, pull `main` and read `ROADMAP.md`. Never work on a row marked `In progress`, and don't edit the files in its **Touches** column. If what you were asked to do overlaps one, tell the person who asked and stop until they decide.
- Claim your row first: set its status to `In progress: Claude for @<login>, <branch>, <date>` and push that one-line change straight to `main`, as the roadmap's "Before you start" section shows. If the push is rejected and the rebase conflicts on your row, someone else got there first.
- If the work has no row, add one (next free ID, right phase) and claim it.
- In the PR that does the work, set the row to `Done: #<PR>`. If you stop early, set it back to `Open`.
- Questions, exploration and reviews that change no files need no claim.

## Report progress to your user

Other people and sessions change `main` while you work. Keep your user told, using `scripts/progress.py`:

- **When you start**, after pulling `main`, run `python3 scripts/progress.py --login <GitHub login of the person you work for>`. It lists what changed since their last commit or roadmap edit. Tell them in a few lines: pull requests merged, roadmap rows finished, rows others have claimed or released, and anything that overlaps what they asked for. Note the `origin/main` commit you started from.
- **Before your final message**, run `python3 scripts/progress.py --since <the commit you started from>` and add a short "Meanwhile on main" note if anything landed while you worked.
- If it reports nothing new, say nothing about it. Summarize; don't paste the whole output.

## Design reference library

Before you design or change any player-facing system (UI, loops, progression, monetization, retention, onboarding, social, live ops, art, audio, performance, safety), read the matching doc in [`docs/reference/`](docs/reference/README.md). Start at its README.

- `docs/reference/safety-compliance.md` overrides everything else. The players are 9 to 15: show real odds before any paid random item (including luck boosts), keep pity timers, never fake a near-miss, sell cosmetics only by direct purchase, no purchase countdowns, and keep codes free.
- When your change alters something a doc describes, update that doc's "Grow A Golem today" section in the same PR.
- New research goes into the library with cited source URLs and a date, following the rules in `docs/reference/README.md`.

## Skills

- [`.claude/skills/auto-ship`](.claude/skills/auto-ship/SKILL.md): when anyone says "ship", "auto-ship <feature>" or "auto-ship #NN", take one change from GitHub issue to merged PR. It routes the work to the matching `docs/reference/` docs (always the safety doc), syntax-checks Luau with `luau-compile --null`, has a fresh subagent review the diff, and merges with a merge commit unless the repo requires a review. The caller is credited, assigned and asked any questions.
