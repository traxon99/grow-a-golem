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
| 18 artifacts (drops, boss drops, hidden relics), index, zone set bonuses, shown odds and bad-luck protection | `ArtifactService` |
| Skill tree (3 branches), respec | `ProgressionService` |
| Awakening (rebirth) and shard upgrades | `ProgressionService` |
| Co-op parties, shared kill rewards, friend bonus | `PartyService` |
| Golem Hub island, Inspect cards, nametag titles, rare-find shout | `SocialService`, `Config.Hub`, `Config.Titles`, client Hub tab |
| Safe artifact trading (spare copies, Ready / countdown / Confirm, policy gate, trade log) | `TradeService`, `Config.Trading`, client Trade tab |
| Global leaderboards | `LeaderboardService` |
| Daily login streak, daily and weekly quests, session gifts, offline mining, group reward | `RewardService` |
| Redeemable codes (Codes box in the Shop) | `CodeService`, `Config.Codes` |
| Limited-time events, event reward tracks, HUD event banner, Events menu | `LiveEventService`, `Config.Events` |
| Game passes, developer products, receipts | `PassService` |
| Roblox policy checks: hides 2x Luck where paid random items are restricted (fails closed) | `PolicyService` |
| Cosmetics: 4 golem skins, 3 wizard outfits, 3 pets, 2 trails, Wardrobe with 3D preview (looks only, never stats) | `CosmeticService`, `Config.Cosmetics`, `src/shared/CosmeticLooks.luau`, client `Wardrobe` |
| Roblox Analytics: onboarding, zone and shop funnels, economy, progression | `AnalyticsService` |
| First-time tutorial (5 steps with pointers, skippable, onboarding funnel) | `TutorialService`, client `Tutorial`, `Config.Tutorial` |
| HUD, next-goal tracker with progress bar, menus | `src/client` |
| UI materials: wood, stone, metal, studs and crystal surfaces, tiling textures | `Ui.surface` in `src/client/Ui.luau`, `Config.UiTextures`, `assets/ui-textures/` |
| Boss health bar, artifact reveal card, level-up banner | `src/client/Moments.luau` |
| Island scenery, lighting | `WorldService`, `src/server/Models/Islands.luau` |
| Enemy and boss models | `src/server/Models/EnemyModels.luau` |
| Walk, punch and slam animation | `src/client/Animator.luau` |
| Sound effects | `src/client/Sfx.luau`, `Config.SoundEffects` |
| Hit flashes, damage numbers, debris | `src/client/Fx.luau` |

Every balance number and all content (zones, enemies, bosses, artifacts, skills, quests, prices) is in `src/shared/Config.luau`.

## Turning on monetization

1. In the [Creator Dashboard](https://create.roblox.com/dashboard/creations), open the experience → **Monetization**.
2. Create the five game passes and five developer products listed in `Config.GamePasses` and `Config.Products`.
3. Paste each id into the matching `id = 0` field. Anything left at `0` shows as "Coming soon" in the Shop.

For the group join reward, set `Config.Group.id` to your Roblox group's id.

**Paid cosmetics** (Frost skin, Starlight Wizard outfit, Ember Sprite and Crystal Owl pets, Rune Trail) are each their own game pass. Create one per item, set its price to the `price` in `Config.Cosmetics`, and paste the id into its `passId`. Until then the Wardrobe shows "Coming soon" (players can still preview them). Earned cosmetics need nothing.

Kid-safe rules for cosmetics, please keep them: every paid cosmetic is a direct purchase of one item the player has previewed. No eggs, crates, spins or "limited stock" timers. If a free random cosmetic drop is ever added, show its real odds and give it a pity limit like `Config.ArtifactPity`.

## UI textures

Panels and buttons already have wood, stone, metal, stud and crystal looks drawn in code. For the full textured look, upload the five PNGs in `assets/ui-textures/` to Roblox (Studio's Asset Manager can bulk import images) and paste each image id into `Config.UiTextures`. Details are in `docs/reference/ui-materials.md`.

## Adding a code

Add a line to `Config.Codes` in `src/shared/Config.luau` and publish:

```lua
SUMMER500 = { reward = { minerals = { copper = 500 } }, expires = 1788220800 },
```

- The name must be UPPERCASE letters and numbers. Players can type it in any case.
- `reward` takes `minerals` and/or `xp`, the same shape as quest rewards.
- `expires` is a UTC unix time (leave it out for a code that never expires). Expired codes tell players to watch for new ones.
- Each player can use a code once. Wrong guesses are rate-limited.
- Keep codes free: never make one depend on following, liking or buying anything.

## Scheduling an event

Events live in `Config.Events`. They switch on and off by themselves on server time (UTC), so you can add one ahead of time and publish whenever.

```lua
{
	id = "halloween2026", -- never reuse an id: it keys saved track progress
	name = "Spooky XP Week",
	description = "Double XP while the moon is out!",
	startsAt = 1792886400, endsAt = 1793491200, -- UTC unix times
	-- or repeat every week: weekly = { day = 6, hour = 0, hours = 48 }, -- day 1 = Monday
	modifiers = { xp = 2 }, -- any of minerals, xp, luck
	track = { ... }, -- optional, see Double Minerals Weekend
},
```

- `modifiers` stack with boosts and passes. Luck changes the artifact odds shown in the Artifacts menu too.
- A `track` gives an event currency earned only by playing while the event is on (`earn` lists how much per enemy, node and boss) and reward tiers to claim. There is no paid way to earn it.
- Unfinished track progress carries over to the next run of the same event, and players can claim earned tiers after it ends, so missing an event isn't punishing.
- Keep it kid-safe: no countdowns on purchases and no "today only" Robux offers.

## Reading the analytics

Everything is logged through Roblox's own `AnalyticsService`, so no data leaves Roblox and nothing personal is sent (no chat, no names). Results show up in the [Creator Dashboard](https://create.roblox.com/dashboard/creations) under the experience's **Analytics** section, usually a few hours after people play. Events don't log from an unpublished Studio place; turn on `Config.Analytics.debug` to print any errors.

| Dashboard view | What it shows |
| --- | --- |
| Onboarding funnel | The 5 tutorial steps, tutorial done, first boss fought, first boss beaten |
| Funnels → Zones | Per island: unlocked, entered, boss fought, boss beaten |
| Funnels → Shop | Shop opened → purchase prompted → purchase completed (per item) |
| Progression | Golem level reached and Awakenings |
| Economy | Each mineral by source (mining, enemy, boss, relic, quest, daily, session, offline, event, code, group, tutorial, purchase) and sink (forge, respec, awaken) |
| Custom events | SpellsCast, ArtifactFound, PartyJoined, CodeRedeemed, EventRewardClaimed |

Mineral income and spell casts are added up and sent once a minute per player to stay inside Roblox's rate limits.

**What to check each week**

1. **D1 and D7 retention** and **average session length** (Overview / Retention). Compare the week before and after each update.
2. **Onboarding funnel**: the biggest drop between two steps is the next thing to fix.
3. **Zones funnel**: where players stall (for example lots of "boss fought" but few "boss beaten" means the boss is too hard).
4. **Economy**: sources versus sinks for each mineral. If a mineral piles up with nothing to spend it on, add a sink; if forge spending is near zero, costs may be too high.
5. **Shop funnel**: items that get prompted but rarely bought may be priced wrong or described badly.

## Code layout

```
src/
  shared/            ReplicatedStorage.Shared
    Config.luau        all balance numbers and content
    Stats.luau         level curve, size, golem stats, costs, unlock checks
    Remotes.luau       remotes (the client only sends intents)
    CosmeticLooks.luau skin colors, pet and outfit shapes (shared so the preview matches)
  server/            ServerScriptService.Server
    init.server.luau   requires and starts every service
    Services/          one module per system (see the table above)
    Models/            golem, enemy and island models built from parts in code
  client/            StarterPlayerScripts.Client
    State.luau         latest server snapshot and menu requests
    Controls.luau      steering and spell input
    Hud.luau           minerals, level, health, spell bar, next goal, messages
    Moments.luau       boss health bar, artifact reveal, level-up banner
    Menus.luau         Forge, Travel, Artifacts, Skills, Awaken, Quests, Events, Party, Hub, Trade, Wardrobe, Shop, Ranks
    Wardrobe.luau      cosmetics list and the spinning 3D preview
    Ui.luau            UI building helpers
    Animator.luau      procedural walk, punch and slam animation
    Sfx.luau           sound effects
    Fx.luau            hit flashes, damage numbers, debris, island tint
```

## Art and sound

Every model is built from plain parts in code, and every limb is a Motor6D joint with a `Kind` attribute (`leg`, `arm`, `body`, `head`, `jaw`, `spin`, `float`). The client animates those joints from how fast the model moves, so no animation assets need uploading. To restyle an enemy, edit its design in `EnemyModels.luau`.

Sounds use audio that ships inside every Roblox client, re-pitched in `Config.SoundEffects`. To use a Creator Store sound instead, right-click it in Studio's Toolbox, choose **Copy Asset ID**, and paste the number as that effect's `id`.

`Config.Visuals` switches off the lighting setup (do this once you tune Lighting by hand), the cloud recolor of the Baseplate, and the island scenery.

The server decides every result (damage, drops, costs, cooldowns, unlocks). The client only says what the player wants to do, and the server checks it.

## Building your own islands

Make an anchored part named `Zone1` (and `Zone2`, `Zone3`, and `Hub` for the Golem Hub) in Workspace. Its top surface becomes that island's playable area, and the game uses it instead of the placeholder. Your own islands don't get the generated scenery, so decorate them however you like. Keep decorations non-colliding (or low), because golems and enemies walk in straight lines and can get stuck on tall solid parts.
