# Gameplay loops

Last updated: 2026-10-29. See also [progression.md](progression.md) and [retention.md](retention.md).

## Rules for agents

1. **Every feature must attach to a loop layer:** 30-second (act and earn), 5-minute (cash out and reinvest for a visible power jump), or session (gate opened, rebirth). If it attaches to none, question it.
2. **The 30-second loop must pay visibly:** a number, pickup or pop every few seconds while the golem fights or mines (inference from the genre skeleton below).
3. **The 5-minute loop must end in a felt power jump:** a forged part should visibly change the golem or its kill speed (inference).
4. **Keep idle and active both rewarding:** offline/idle gains below active play, never zero (inference; see [retention.md](retention.md)).
5. **Timers set rhythm, not purchase pressure.** Restocks, events and boss respawns are fine; a timer next to a Robux button is not ([safety-compliance.md](safety-compliance.md)).
6. **Robux compresses time; it never gates the loop** (inference, low-confidence source below).
7. **Server owns the loop.** Client sends intents only; kills, drops and rewards are computed on the server.
8. **Readability over polish:** a clear loop matters more than art for this genre (inference from Grow a Garden's reception).

## Grow A Golem today: active mineral rush

Mineral nodes occasionally show a glowing **Vein Rush** weakspot after spawning. A
nearby player can tap the first and then the second marked ore chunk using the
native Roblox proximity prompt (keyboard, gamepad or touch). The first prompt
lasts 7 seconds and the follow-up lasts 4 seconds. Completing both earns a
**fixed +50% of that node's base mineral yield** (rounded down, minimum 1),
processed through the usual mineral multipliers. Each node pays this bonus
at most once; a missed attempt can reappear after 45 seconds. Other players
cannot finish somebody else's sequence. Automatic mining, node ownership and
normal node rewards continue unchanged. No purchase, retry fee or progression
gate is involved. Server validates the deadlines and proximity. Studio phone
and gamepad playtesting is still required.

## What top games do

All top genres share one skeleton: a fast action that pays (click, cast, plant, kill) → a cash-out (sell/collect) → reinvest in a multiplier (upgrade, rod, seed, pet) → the multiplier opens a gate (zone, sea, island, rebirth). Timers (restocks, weather, nights, payouts) pace the 5-minute layer. Loop-duration readings below are interpretations of mechanics; no source measures them.

| Game | 30 s | 5 min | Session |
|---|---|---|---|
| Grow a Garden | Harvest, plant | Seed restock (every 5 min, global), sell, buy rarer seed | Weather mutations, expand garden |
| Steal a Brainrot | Buy off conveyor, place | Income ticks; raid or defend | Build to rebirth |
| 99 Nights in the Forest | Gather wood | One day/night cycle | A run toward 99 nights; diamonds persist |
| Fisch | Cast, shake, reel | Sell, buy rod/boat | Next island or sea |
| Anime TD (AFK portal) | Auto-replay | Payout per best-clear interval | Unlock stages |

Details:
- **Grow a Garden:** buy, plant, harvest, sell, reinvest; crops grow offline ([esports.gg](https://esports.gg/news/roblox/grow-a-garden-breaks-blox-fruits-record-for-most-concurrent-users-on-roblox/)). Seed shop restocks every 5 minutes, top seeds sell out in seconds; weather such as Rain gives +50% growth and a mutation; selling with friends gives +10% (fan guide, [itemlevel.net](https://itemlevel.net/complete-beginners-guide-for-grow-a-garden-roblox/)).
- **Steal a Brainrot:** placed units earn per second; stealing uses an interruptible progress bar; locks and shields defend ([playnews.gg](https://www.playnews.gg/en/guides/steal-a-brainrot-roblox-the-complete-strategy-rebirth-and-tier-list-guide-for-july-2026); [Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot)).
- **99 Nights:** night countdown from load-in; campfire, crafting bench tiers; threats escalate by night; diamonds buy persistent classes ([PC Gamer](https://pcgamer.com/games/roblox/99-nights-in-the-forest-tips/)).
- **Fisch:** cast timing, shake clicks cut bite wait by about 0.5 s each, reel minigame; a bestiary acts as collection book ([Destructoid](https://www.destructoid.com/fisch-roblox-beginners-guide/)).
- **Anime Expeditions AFK portal:** pays every fastest-clear interval (e.g. 3 min); normal lobbies idle-kick after about 5 min; VIP R$320 speeds AFK payouts 25% ([allthings.how](https://allthings.how/anime-expeditions-afk-mode-in-roblox-how-the-afk-world-works/)).
- **Simulators:** PS99 pets auto-collect; Bee Swarm rewards leaving the client open rather than true offline progress ([RoWatcher, low confidence](https://rowatcher.com/news/the-afk-revolution-how-idle-mechanics-conquered-roblox)).
- **Why it matters:** the 2025 megahits (Grow a Garden, Steal a Brainrot, 99 Nights) all run simple loops with passive income and scheduled events; Steal a Brainrot drew 26.4B visits in Q3 2025 ([Newzoo via GameDevReports](https://gamedevreports.substack.com/p/newzoo-top-roblox-games-in-2025)). Grow a Garden was called "a pretty standard AFK game" yet peaked above 21M CCU ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)).
- Not verified this pass: Tower Defense Simulator, Anime Defenders, Dead Rails, Bee Swarm, classic tycoon specifics.

## Grow A Golem today

| Layer | Our loop |
|---|---|
| 30 s | Golem auto-fights and auto-mines; eight minerals (stone through aether) and XP drop; damage numbers, hit flashes, debris; spells Q/E/R (Quake, Mend, Magnet) for active players |
| 5 min | Forge parts into 5 slots across 8 tiers (full-set bonus); playtime gift at 5 min; daily quests |
| Session | Golem size steps (levels 1/5/10/18/28/40/55/75/100) plus boss kills unlock the next island (Mossy Quarry → Ember Flats → Glasswood → Storm Peak → Sunken Ruins → Sky Forge); each boss cycles three telegraphed attacks (circle, narrow lane, broad sweep) to dodge; artifacts; Awakening at level 20+; Ascension after five unspent Awakenings and boss 6 |

- Strong fit with the genre skeleton. Co-op parties add a social multiplier (see [social.md](social.md)).
- Falling four studs below an island's surface knocks the golem out immediately, at any size. It returns to that island's spawn with no falling momentum, stays down for the normal five-second recovery, and then reforms at full health. Falling never removes saved progress.
- Mineral nodes award their fixed yield to the highest damage contributor, not whoever lands the final chip; ties favor the lower UserId, and departed players cannot collect.
- Ordinary enemy kills credit each player who dealt at least 25% of max health, plus nearby party members (deduplicated). If a large crowd splits damage below 25% each, the top contributor receives credit. Enemies that fall below the island count as defeats for qualifying contributors; party range is measured from the last hit location. Untouched enemies disappear without rewards.
- Bosses award drops, artifact rolls, quests and island unlocks only to contributors whose golem is still active on that boss's island when it dies. Tower wave rewards still use their own fixed path.
- **Active boss dodging (#195, part of #81):** Each island boss rotates through a circle centered on its target, a long narrow lane in front of the boss, and a short broad sweep. Red ground shapes show the exact damage footprint during the existing warning interval; the server checks the same fixed shape at impact. Move out to dodge; no purchase or extra reward is involved. Tower enemies without the new pattern list keep the original circular attack. Studio/mobile validation remains pending.
- **Perfect Quake boss stagger (#201, part of #81):** A server-graded perfect second Quake press that hits a living island boss interrupts its current warning and opens a visible blue-and-gold 1.5-second stagger. The boss cannot chase, melee or slam during that opening; the next slam waits another 0.5 seconds. Each boss can be staggered at most once per 10 seconds, even if several players cast together. Ordinary Quake still works normally; Tower bosses and regular enemies cannot be staggered. No purchases or random rewards. Studio multiplayer and device validation remain pending.
- **Riding (#185).** Mounted, the golem is the main character: the rider's root is welded to a `RiderMount` attachment on the golem's right shoulder, plays a sit pose, collides with nothing and doesn't walk, and the camera orbits the golem (focus raised `Config.Golem.cameraHeight`, zoom set to `cameraDistance` on climbing on and free between `cameraMinZoom` and `cameraMaxZoom`, all scaled by golem size). Move, sprint and spells steer the golem, and the rider can still attack and cast with the golem's stats. A session starts mounted, and a respawned rider goes straight back on.
- **Mount and dismount (#123, #185).** F, gamepad R1, or the HUD button, one request per `mountCooldown` (1 s), validated by the server: climbing on needs the rider alive and within `mountRange` of the golem. The rider and camera blend over in `mountBlendTime` (instant with Reduced Motion). Dismounting stands the rider on solid ground beside the golem (right side first, raycast for walls and a floor, then left, behind and in front), and the camera, walking and jumping return to the character.
- **Dismounted companion (#185).** Steering, sprint and spells are ignored (the client doesn't send them; the server refuses them). The golem stays on a leash around the rider: it fights and mines only inside `followRadius` (30 studs, scaled by size), walks back when it strays until it is inside `followStop` of the radius, and puffs back beside the rider (a dust puff, none with Reduced Motion) beyond `leashTeleportRadius` or after `stuckTime` seconds without getting closer. It travels with the rider between islands.
- **Upgrades keep the rider on (#98, #185).** Forge upgrades, cosmetics, level size steps and mesh-art loads restyle the golem in place: the model, root, humanoid and rider mount stay, and only body parts, pet and trail are swapped, with the mount and camera framing moved for a new size. HP, mounted state, facing, velocity, sprint and spell cooldowns carry through.
- **Optional timed Quake (#197, part of #81):** Quake's first press still deals normal damage after a 0.9-second windup. During the windup, a separate high-contrast gold cue invites a second press of the same Quake key/gamepad button or a touch button. One press in the server-graded 0.44-second window grants exactly +50% Quake damage; an early, late or skipped press leaves normal damage. The server uses its own receive time and ignores repeated attempts; the client displays only a synchronized cue. No purchases or progression gates. Studio phone/gamepad latency testing remains pending.
- **Quake slam (#172).** Quake no longer hits on the key press. The golem raises both arms for `Config.Spells.quake.windup` (0.9 s), then slams: the server applies the damage and the ring at that moment and tells clients (`quakeImpact`) so they play the blast, rocks and thud. If the golem is knocked out or removed in the windup, nothing lands and nobody is told. The cooldown still starts on the cast.
- **Sprint (#172).** Hold Shift (gamepad L3) or tap the HUD Sprint button to raise walk speed by `Config.Golem.sprintMult` (1.6x). It is a validated client request (`SprintGolem`, boolean only, 0.1 s between changes) and only counts while a mounted rider is steering, so a golem playing itself never sprints; dismounting or a knock-out ends it. The server publishes what it honours as the `GolemSprint` player attribute and the client repeats its request until they agree, so a dropped request never leaves them out of step. It has no cost or cooldown.
- A detached rider also dies immediately below the kill plane, even when their golem is still on land. The character respawns normally, and its golem uses the same fall recovery.
- **Golem Tower (#62, off until playtested):** a session-layer side mode. Ten waves of an unlocked island's enemies in a private arena, with fixed, pre-shown rewards per cleared wave instead of drops. It gives parties a shared goal without a new random reward table.
- **Shared mineral surge (#150):** every 15 minutes on a UTC-aligned schedule, mineral nodes on every island pay exactly 2x their normal rounded mining yield for 90 seconds. A gameplay-only HUD banner counts down during the preceding 60 seconds and while active. The server computes payouts; the client clock is display-only. Participation is logged once per player per surge. No purchase prompts, paid skips, random rewards or entry gates. This is a shared rhythm, not yet a co-op world boss.
- Each island now has weighted swarmer/tank spawns; every twentieth successful spawn is an elite with more fixed XP/minerals. The 20-hour completion goal is unmeasured.
- Unknown until playtest (#9): whether the first forge feels like a power jump, and how long each zone takes.

## Gaps worth closing

1. **P0 (#9):** Measure loop times in a playtest: seconds between rewards, minutes to first forge, minutes per zone. Write results here.
2. **P1:** Make each forge tier visibly change the golem model (size, color, material) so the 5-minute jump is felt.
3. **P1 (#15):** Add a shared global timer beat, e.g. a world boss or mineral surge every N minutes (inference from Grow a Garden restocks).
4. **P2 (#15):** More zones and enemy variety; three islands is thin for session-layer goals.
5. **P2:** Show per-minute mineral rate in the stats panel (idle-game convention, low confidence).

## Sources

All accessed 2026-10.
- esports.gg, Grow a Garden record: https://esports.gg/news/roblox/grow-a-garden-breaks-blox-fruits-record-for-most-concurrent-users-on-roblox/
- itemlevel.net, Grow a Garden beginner guide: https://itemlevel.net/complete-beginners-guide-for-grow-a-garden-roblox/
- playnews.gg, Steal a Brainrot guide (July 2026): https://www.playnews.gg/en/guides/steal-a-brainrot-roblox-the-complete-strategy-rebirth-and-tier-list-guide-for-july-2026
- Wikipedia, Steal a Brainrot: https://en.wikipedia.org/wiki/Steal_a_Brainrot
- Wikipedia, Grow a Garden: https://en.wikipedia.org/wiki/Grow_a_Garden
- PC Gamer, 99 Nights tips: https://pcgamer.com/games/roblox/99-nights-in-the-forest-tips/
- Destructoid, Fisch beginner guide: https://www.destructoid.com/fisch-roblox-beginners-guide/
- allthings.how, Anime Expeditions AFK mode: https://allthings.how/anime-expeditions-afk-mode-in-roblox-how-the-afk-world-works/
- RoWatcher, AFK revolution (low confidence): https://rowatcher.com/news/the-afk-revolution-how-idle-mechanics-conquered-roblox
- Newzoo via GameDevReports, top Roblox games 2025: https://gamedevreports.substack.com/p/newzoo-top-roblox-games-in-2025
