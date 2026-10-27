# Grow A Golem

A 3D idle auto-battler for Roblox. You ride on the shoulder of a golem you build from the minerals you mine, and you grow it into a titan as it fights its way across a chain of floating islands.

Game code lives in this repo and syncs into Roblox Studio with [Rojo](https://rojo.space). Maps, models, and UI art are built in Studio.

## Setup (one time)

1. Install Rojo 7. The easiest way is the **Rojo** extension for VS Code, or `rokit add rojo-rbx/rojo` if you use Rokit.
2. In Roblox Studio, install the **Rojo** plugin (Plugins tab → Manage Plugins, or from the Creator Store).
3. Open a new **Baseplate** place in Studio, then go to Game Settings → Security and turn on **Enable Studio Access to API Services**. Without this, progress won't save in Studio.

## Running it

1. In this folder, run `rojo serve` (or use "Rojo: Start server" in VS Code).
2. In Studio, open the Rojo plugin and click **Connect**.
3. Press **Play**. A test island appears 60 studs up, your golem spawns, and you're seated on its shoulder.

## Controls

| Action | PC | Mobile / gamepad |
| --- | --- | --- |
| Steer the golem | WASD | Thumbstick |
| Quake (area damage) | Q | Quake button / X |
| Let the golem play itself | Let go of the controls | Let go of the controls |

When you aren't steering, the golem goes after enemies within 35 studs, and once the area is clear it walks to the nearest mineral node and mines it.

## Code layout

```
src/
  shared/            ReplicatedStorage.Shared
    Config.luau        every balance number (stats, zones, enemies, nodes)
    Remotes.luau       RemoteEvents (client sends intents only)
  server/            ServerScriptService.Server
    init.server.luau   starts the services
    Services/
      WorldService     zone ground, spawn points, workspace folders
      DataService      load/save player data (DataStore), leaderstats
      GolemService     builds the golem, seats the rider, health, steering
      EnemyService     spawns enemies, chase-and-hit AI, kill rewards
      MiningService    mineral nodes and mining rewards
      CombatService    10 Hz game loop: golem auto-battle, mining, spells
  client/            StarterPlayerScripts.Client
    Controls.luau      steering and spell input
    Hud.luau           minerals, XP, golem health, Quake button
```

All results (damage, drops, minerals, cooldowns) are decided on the server. The client only says "steer this way" or "cast Quake", and the server checks it.

## Building your own zone

Make an anchored part named `Zone1` in Workspace. Its top surface becomes the playable area, and the game will use it instead of the placeholder island.

## Status

Milestone 1, "Ride and fight", is done: riding, steering, auto-battle, mining, the Quake spell, and saving. See the build plan for milestones 2 to 7.
