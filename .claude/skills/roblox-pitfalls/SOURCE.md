# Source

`SKILL.md` is copied unchanged from [JoCoding-Inc/roblox-skills](https://github.com/JoCoding-Inc/roblox-skills), path `plugins/roblox-skills/skills/roblox-pitfalls/SKILL.md`, at commit `448ef47e8e66dad57cee936572ad1d1471738590` (2026-10-26). It is MIT licensed; the license is in `LICENSE` next to this file. The upstream `NOTICE.md` credits the sources listed in the skill's front matter.

To update it, copy the file again from upstream and change the commit above. Keep repo-specific rules here and in `CLAUDE.md`, not in `SKILL.md`, so the copy stays a clean upstream file.

## Notes for this repo

- It points to `roblox-studio-mcp`, `roblox-cloud`, `roblox-tooling` and `roblox-data` from [TabooHarmony/roblox-brain](https://github.com/TabooHarmony/roblox-brain), which aren't installed. For Studio MCP use the "Driving Roblox Studio" section of `CLAUDE.md`.
- Saves use our own session leases (PR #37), so check `src/` before applying its DataStore advice.
