# Grow A Golem: notes for agents

Read `README.md` for setup, the code layout and where each system lives.

## Issues: check and claim before you start

More than one person, and more than one Claude session, works on this repo at once. Work is tracked in GitHub issues grouped into phase milestones, and [`CONTRIBUTING.md`](CONTRIBUTING.md) is the workflow definition: how to find, claim, finish, release and add work. Read it before any work and follow the version on `main`, since it may have changed since you last saw it.

- Never work on an issue labelled `in progress` by someone else, and don't edit the files in its **Touches** field. If what you were asked to do overlaps one, tell the person who asked and stop until they decide.
- Claim your issue first, as `CONTRIBUTING.md` says. A Claude session assigns the login of the person it works for and comments `Claiming: Claude for @<login>, branch <branch>, <date>`. If an earlier claim shows up when you re-read the issue, someone else got there first.
- If the work has no issue, create one as `CONTRIBUTING.md`'s "Adding work" says, and claim it.
- The PR that does the work says `Fixes #<issue>`. If you stop early, release the issue.
- Questions, exploration and reviews that change no files need no claim.

## Report progress to your user

Other people and sessions change `main` while you work. Keep your user told, using `scripts/progress.py`:

- **When you start**, after pulling `main`, run `python3 scripts/progress.py --login <GitHub login of the person you work for>`. It lists what changed since their last commit or merge. Tell them in a few lines: pull requests merged, issues finished, issues others have claimed or released, and anything that overlaps what they asked for. Note the `origin/main` commit you started from.
- **Before your final message**, run `python3 scripts/progress.py --since <the commit you started from>` and add a short "Meanwhile on main" note if anything landed while you worked.
- If it reports nothing new, say nothing about it. Summarize; don't paste the whole output.

## Design reference library

Before you design or change any player-facing system (UI, loops, progression, monetization, retention, onboarding, social, live ops, art, audio, performance, safety), read the matching doc in [`docs/reference/`](docs/reference/README.md). Start at its README.

- `docs/reference/safety-compliance.md` overrides everything else. The players are 9 to 15: show real odds before any paid random item (including luck boosts), keep pity timers, never fake a near-miss, sell cosmetics only by direct purchase, no purchase countdowns, and keep codes free.
- When your change alters something a doc describes, update that doc's "Grow A Golem today" section in the same PR.
- New research goes into the library with cited source URLs and a date, following the rules in `docs/reference/README.md`.

## Skills

- [`.claude/skills/auto-ship`](.claude/skills/auto-ship/SKILL.md): when anyone says "ship", "auto-ship <feature>" or "auto-ship #NN", take one change from GitHub issue to merged PR. It routes the work to the matching `docs/reference/` docs (always the safety doc), syntax-checks Luau with `luau-compile --null`, has a fresh subagent review the diff, and merges with a merge commit unless the repo requires a review. The caller is credited, assigned and asked any questions.

## Driving Roblox Studio (MCP)

Studio ships its own MCP server, so Claude Code can play-test, read Output, inspect the place and run Luau. Nothing extra to install, and no keys are involved. Docs: https://create.roblox.com/docs/studio/mcp

- **Studio side:** Assistant → **… → Manage MCP Servers** → turn on **Enable Studio as MCP server**. A green dot there means it's serving.
- **Claude Code side:** turn on **Claude Code** under Assistant Settings → MCP Servers → **Quick connect**, or run one of these and restart Claude Code:
  - Windows: `claude mcp add --scope user Roblox_Studio -- cmd.exe /c "%LOCALAPPDATA%\Roblox\mcp.bat"`
  - macOS: `claude mcp add --scope user Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`
- **Using it:** call `list_roblox_studios` first, since every other tool needs its `studio_id`. Then `start_stop_play` to play-test, `get_console_output` for Output, `search_game_tree` / `inspect_instance` to look around, `execute_luau` to run code.
- Code is synced by Rojo, so fix scripts in `src/`, not in Studio. Studio-side script edits are overwritten on the next sync.
- **Won't connect?** Studio must be open with the toggle on. On Windows, `mcp.bat` hard-codes a Studio version folder and can go stale after a Studio update; toggle **Enable Studio as MCP server** off and on, which rewrites it, then restart Claude Code.