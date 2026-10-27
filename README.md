# Grow A Golem

A 3D idle auto-battler for Roblox. You ride on the shoulder of a golem you build from the minerals you mine, and you grow it into a titan as it fights its way across a chain of floating islands.

Game code lives in this repo and syncs into Roblox Studio with [Rojo](https://rojo.space). Maps, models, and UI art are built in Studio.

## Setup (one time)

1. Install Rojo 7. The easiest way is the **Rojo** extension for VS Code, or `rokit add rojo-rbx/rojo` if you use Rokit.
2. In Roblox Studio, install the **Rojo** plugin (Plugins tab → Manage Plugins, or from the Creator Store).
3. Open a new **Baseplate** place in Studio and publish it with **File → Publish to Roblox** (it can stay private). Then go to Game Settings → Security and turn on **Enable Studio Access to API Services**. Without both steps the game still runs, but progress and leaderboards won't save, and the Output window will warn you about it.

## Running it

1. In this folder, run `rojo serve` (or use "Rojo: Start server" in VS Code).
2. In Studio, open the Rojo plugin and click **Connect**.
3. Press **Play**. Three test islands appear in the sky, your golem spawns on the first one, and you're seated on its shoulder.

## Controls

| Action | PC | Gamepad | Mobile |
| --- | --- | --- | --- |
| Steer the golem | WASD | Left stick | Joystick |
| Quake (area damage) | Q | X | Quake button |
| Mend (heal) | E | Y | Mend button |
| Magnet (2x minerals for 10 s) | R | B | Magnet button |
| Menus | Buttons on the left | | Buttons on the left |

Let go of the controls and the golem plays itself: it fights enemies nearby, and once the area is clear it walks to mineral nodes and mines them.

## What's in the game

| System | Where it lives |
| --- | --- |
| Riding, steering, auto-battle, mining | `GolemService`, `CombatService`, `MiningService` |
| Forging parts (5 slots × 4 tiers), growth in size, full-set bonus | `ProgressionService`, `Stats` |
| 3 islands with gates, travel menu, zone bosses with a dodgeable slam | `WorldService`, `EnemyService` |
| 18 artifacts (drops, boss drops, hidden relics), index, zone set bonuses | `ArtifactService` |
| Skill tree (3 branches), respec | `ProgressionService` |
| Awakening (rebirth) and shard upgrades | `ProgressionService` |
| Co-op parties, shared kill rewards, friend bonus | `PartyService` |
| Global leaderboards | `LeaderboardService` |
| Daily login streak, daily and weekly quests, session gifts, offline mining, group reward | `RewardService` |
| Game passes, developer products, receipts | `PassService` |
| HUD, next-goal tracker, menus | `src/client` |

Every balance number and all content (zones, enemies, bosses, artifacts, skills, quests, prices) is in `src/shared/Config.luau`.

## Turning on monetization

1. In the [Creator Dashboard](https://create.roblox.com/dashboard/creations), open the experience → **Monetization**.
2. Create the five game passes and five developer products listed in `Config.GamePasses` and `Config.Products`.
3. Paste each id into the matching `id = 0` field. Anything left at `0` shows as "Coming soon" in the Shop.

For the group join reward, set `Config.Group.id` to your Roblox group's id.

## Code layout

```
src/
  shared/            ReplicatedStorage.Shared
    Config.luau        all balance numbers and content
    Stats.luau         level curve, size, golem stats, costs, unlock checks
    Remotes.luau       remotes (the client only sends intents)
  server/            ServerScriptService.Server
    init.server.luau   requires and starts every service
    Services/          one module per system (see the table above)
  client/            StarterPlayerScripts.Client
    State.luau         latest server snapshot and menu requests
    Controls.luau      steering and spell input
    Hud.luau           minerals, level, health, spell bar, next goal, messages
    Menus.luau         Forge, Travel, Artifacts, Skills, Awaken, Quests, Party, Shop, Ranks
    Ui.luau            UI building helpers
```

The server decides every result (damage, drops, costs, cooldowns, unlocks). The client only says what the player wants to do, and the server checks it.

## Building your own islands

Make an anchored part named `Zone1` (and `Zone2`, `Zone3`) in Workspace. Its top surface becomes that island's playable area, and the game uses it instead of the placeholder.
