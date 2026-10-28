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
- [`.claude/skills/ship`](.claude/skills/ship/SKILL.md): `/ship` is a shorter alias that runs `auto-ship` with the same arguments.
- [`.claude/skills/roblox-ui-genre-studs`](.claude/skills/roblox-ui-genre-studs/SKILL.md): the chunky stud look for Roblox simulator UI (black outlines, lips, gradients, HUD zones, motion, anti-slop checks), from [JoCoding-Inc/roblox-skills](https://github.com/JoCoding-Inc/roblox-skills) (MIT, see its `SOURCE.md`). Use it for HUD, shop and panel work alongside `docs/reference/ui-ux.md` and `ui-materials.md`. Where they differ, `safety-compliance.md` wins first, then our mystical theme (#83: rune, crystal and arcane palette and motifs) over its colour ramps, then the reference docs. Its numbers are starting values, so check them against a Studio screenshot.
- [`.claude/skills/roblox-pitfalls`](.claude/skills/roblox-pitfalls/SKILL.md): field notes on Roblox failures (Open Cloud publish errors, Creator Store model loading, testing through Studio MCP, engine limits such as teleports in Studio and light range). Read it before publishing, loading third-party models, or when something passes offline tests but breaks in Studio.
- [`.claude/skills/roblox-blender-export`](.claude/skills/roblox-blender-export/SKILL.md): getting Blender meshes into Studio (scale, pivot, axis, FBX export call, palette textures, triangle budgets, import settings, preview renders). **Skip its section 8**: it uses the community "MCP for Blender" add-on, and we use only the official Blender Lab MCP below.
- [`.claude/skills/roblox-store-art-pack`](.claude/skills/roblox-store-art-pack/SKILL.md): vetting and quarantining Creator Store assets, the map composition check, icon families, and the game icon and thumbnails. **Skip its section 1** (bright daylight simulator palette); our zones and mystical theme set the look.

These three and the stud UI skill come unchanged from [JoCoding-Inc/roblox-skills](https://github.com/JoCoding-Inc/roblox-skills) (MIT); each folder's `SOURCE.md` has the commit and repo notes. They mention companion skills from roblox-brain that aren't installed here.

## Codex plugin

`.claude/settings.json` registers OpenAI's [`openai/codex-plugin-cc`](https://github.com/openai/codex-plugin-cc) marketplace and enables `codex@openai-codex`, so Claude Code offers to install it when you trust the folder. The plugin only drives Codex: the machine also needs the Codex CLI and an OpenAI login. Run `/codex:setup` to check, and it can install the CLI through npm. Cloud sessions may not have either, so don't count on it there.

## Driving Roblox Studio (MCP)

Studio ships its own MCP server, so Claude Code can play-test, read Output, inspect the place and run Luau. Nothing extra to install, and no keys are involved. Docs: https://create.roblox.com/docs/studio/mcp

- **Studio side:** Assistant → **… → Manage MCP Servers** → turn on **Enable Studio as MCP server**. A green dot there means it's serving.
- **Claude Code side:** turn on **Claude Code** under Assistant Settings → MCP Servers → **Quick connect**, or run one of these and restart Claude Code:
  - Windows: `claude mcp add --scope user Roblox_Studio -- cmd.exe /c "%LOCALAPPDATA%\Roblox\mcp.bat"`
  - macOS: `claude mcp add --scope user Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`
- **Using it:** call `list_roblox_studios` first, since every other tool needs its `studio_id`. Then `start_stop_play` to play-test, `get_console_output` for Output, `search_game_tree` / `inspect_instance` to look around, `execute_luau` to run code.
- Code is synced by Rojo, so fix scripts in `src/`, not in Studio. Studio-side script edits are overwritten on the next sync.
- **Won't connect?** Studio must be open with the toggle on. On Windows, `mcp.bat` hard-codes a Studio version folder and can go stale after a Studio update; toggle **Enable Studio as MCP server** off and on, which rewrites it, then restart Claude Code.

## Driving Blender (MCP)

We use only Blender Lab's official Blender MCP (https://www.blender.org/lab/mcp-server/), Blender 5.1 or newer. It has two parts: an add-on inside Blender that listens on `localhost:9876`, and an MCP server that Claude Code launches. Nothing about it goes in this repo.

- **Add-on:** in Blender, add the extensions repository `https://lab.blender.org/` (Preferences → Get Extensions → Repositories), then install and enable **MCP**. Allow online access (Preferences → System), which it needs to open its socket. The server auto-starts; its add-on preferences show "Server is running".
- **MCP server:** download the `.mcpb` bundle from the page above (it's a zip), extract it somewhere permanent such as `~/.blender-mcp/<version>`, and register it with [uv](https://docs.astral.sh/uv/):
  `claude mcp add --scope user blender -- uv run --directory <that folder> blender-mcp`
  Then restart Claude Code. The first run installs its Python dependencies.
- **Tools:** `get_objects_summary`, `get_object_detail_summary`, the `get_blendfile_summary_*` family, screenshots (`get_screenshot_of_area_as_image`, `get_screenshot_of_window_as_image`), `render_viewport_to_path`, API and manual search, and `execute_blender_code` for any Python in the live session. Save the .blend before letting Claude edit it.
- The add-on's socket has no authentication, so keep it on localhost. Don't run another Blender MCP add-on at the same time; they default to the same port.
