# Contributing: how work is tracked and claimed

This file is the workflow definition for Grow A Golem. Everyone follows it, people and Claude sessions alike, and the repo's skills (such as `auto-ship`) read it instead of keeping their own copy. If you change how work is claimed or tracked, change it here.

All work lives in [GitHub issues](https://github.com/traxon99/grow-a-golem/issues), grouped into [milestones](https://github.com/traxon99/grow-a-golem/milestones). **Check the issue and claim it before you start.**

## Where the project stands

The game is written but has never been played. All Luau files compile and pass the offline tests in CI, but none of the code has run in Roblox Studio or a published place. So the "Phase 1: Make it run" milestone comes before everything else.

The umbrella issues are [#9](https://github.com/traxon99/grow-a-golem/issues/9) (playtest and pacing), [#15](https://github.com/traxon99/grow-a-golem/issues/15) (content and balance) and [#16](https://github.com/traxon99/grow-a-golem/issues/16) (art and launch); their tasks are sub-issues. Details live in [`docs/playtest.md`](docs/playtest.md), [`docs/expansion-design.md`](docs/expansion-design.md) and [`docs/launch/plan.md`](docs/launch/plan.md).

## How work is organized

- **Milestones are phases**, in order: Phase 1 Make it run, Phase 2 Tune pacing, Phase 3 Launch prep, Phase 4 Soft launch, Phase 5 Grow. Each milestone's description states its gate: what has to be true before the next phase starts.
- **Each task is one issue** in its phase's milestone. Tasks moved from the old `ROADMAP.md` keep their row ID at the start of the title (`R1.3: …`, `B1: …`), so older notes that name an ID still find the issue by search.
- **The issue body** says what to do and has two fields every task needs:
  - **Touches:** the files (or parts of files) the work changes. While the issue is claimed, nobody else edits them.
  - **Blocked by:** what it waits on, when it can't start yet.

### Labels

| Label | Meaning |
| --- | --- |
| `in progress` | Claimed. The assignee is on it. Don't work on it, and don't edit the files in its **Touches** field. |
| `blocked` | Can't start yet, for the reason in **Blocked by**. |
| `needs: studio` | Someone has to run the game in Roblox Studio. A cloud Claude session can't. |
| `needs: owner` | Needs the owner's Roblox account (traxon99): the Creator Dashboard, the Roblox group or ad spend. |
| `needs: code` | Can be done entirely in this repo, by a person or a Claude session. |
| `bug` | A problem found while testing. |
| `priority: P0` / `P1` / `P2` | How urgent it is. |

An issue's status follows from these: open with no `in progress` label is free to claim; `in progress` with an assignee is taken; closed as completed is done (the closing PR is linked on the issue).

## Before you start

1. Pull the latest `main` and find the issue for your work. List what's taken: [open issues labelled `in progress`](https://github.com/traxon99/grow-a-golem/issues?q=is%3Aissue+is%3Aopen+label%3A%22in+progress%22) (`gh issue list --label "in progress"`).
2. Skip every issue labelled `in progress`, and stay out of the files in its **Touches** field. If you must change one of those files, comment on that issue and ask its assignee first. Skip `blocked` issues until their blocker is closed.
3. **Claim the issue.** In this order:
   1. Add the `in progress` label and assign yourself. A Claude session assigns the GitHub login of the person running it.
   2. Comment `Claiming: <who>, branch <branch>, <today's date>`. For a Claude session, `<who>` is `Claude for @<login>`.
   3. Read the issue again. If someone else was assigned or posted a claim comment before yours, the earlier claim wins: remove yourself and your label change, delete your comment, and pick another issue.
4. Branch off `main` and do the work.

## When you finish

- Open the PR with `Fixes #<issue>` in its body, so the issue closes when the PR merges, not before.
- If the work turned up new tasks, file them as new issues (see [Adding work](#adding-work)) and link them in the PR.

## If you stop

- Unassign yourself, remove the `in progress` label, and comment on the issue with where you left the branch.
- A claim with no new commits on its branch for 7 days is stale. Ask on the issue; if nobody answers within 2 days, anyone may release it as above.

## Adding work

- New task: search open and closed issues first, then create one in the right milestone with a `needs:` label, a **Touches** field and, if it waits on something, the `blocked` label and a **Blocked by** field. Then claim it as above.
- Bug found while testing: create an issue labelled `bug` in the milestone you were testing, with **Found by** and **Touches** fields.
- Sub-tasks of an umbrella issue (#9, #15, #16) go in as its sub-issues.

## Catching up

`scripts/progress.py` lists the pull requests merged and the issues done, claimed, released or added since a point you choose, then the issues in progress and the open PRs:

```sh
python3 scripts/progress.py --login <your GitHub login>   # since your last commit or merge
python3 scripts/progress.py --since <commit, YYYY-MM-DD, 12h or 3d>
```

It needs `git`, plus `gh` signed in for the issue and PR parts. Claude sessions run it when they start and before they finish, and tell their user what changed (see `CLAUDE.md`).
