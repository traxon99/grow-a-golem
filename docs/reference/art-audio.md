# Art, audio and visual style

Last updated: 2026-10-27. See also [ui-ux.md](ui-ux.md), [performance-mobile.md](performance-mobile.md) and `images/rarity-colors.png`.

![Rarity colors](images/rarity-colors.png)

![Artifact reveal card](images/reward-popup.png)

## Rules for agents

1. **Readable and bright beats detailed.** Low-poly, flat colors and built-in materials are fine for this genre and cheap on mobile (inference from Grow a Garden's reception; materials cost from [Design for performance](https://create.roblox.com/docs/en-us/performance-optimization/design)).
2. **Rarity colors always come with a symbol or label** for color-blind players ([Accessibility](https://create.roblox.com/docs/en-us/production/publishing/accessibility.md)). Use one shared rarity table in Config; see `images/rarity-colors.png`.
3. **Default rarity ladder** (common practice, unverified): Common gray/white, Uncommon green, Rare blue, Epic purple, Legendary gold/orange, Mythic red/pink; animated/rainbow above that.
4. **Juice is gated on `ReducedMotionEnabled`:** button bounces, pop-ins, camera shake and slides become a snap or fade ([Accessibility](https://create.roblox.com/docs/en-us/production/publishing/accessibility.md)).
5. **Reveal animations show the real roll.** No fake near-miss spins (see [safety-compliance.md](safety-compliance.md)).
6. **Never signal an event by sound alone;** give separate SFX and music volume controls (same Accessibility source).
7. **Only use audio we uploaded or Roblox's licensed library,** and grant our universe permission to each asset, or it plays silent ([Asset privacy](https://create.roblox.com/docs/projects/assets/privacy)).
8. **Thumbnails: 16:9, 1920x1080, 2-5 active,** key art away from the bottom edge, no "50% off" style claims, alt text on each ([Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)).
9. **Keep combat cartoon-light:** no blood or gore, to stay Minimal/Mild ([Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)).

## What top games do

### Style
- **Grow a Garden** uses studded textures recalling old-school Roblox and a classical soundtrack, including public-domain Mozart; Kotaku said it looks more like a prototype ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)).
- **Steal a Brainrot** uses voxel meme characters; PC Gamer called its events "sensory overload" ([Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot)).
- The cartoony simulator UI look is sold as reusable kits (see [visual-references.md](visual-references.md)).
- PS99 tier names (Basic through Celestial) show games use their own rarity names; no per-game color source found ([PS99 wiki](https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99))).

### Juice (common practice, unverified)
Button scale-bounce about 1.05-1.1x over 0.1 s; click SFX on every button; pop scale-in for reward cards; floating "+123" numbers; particle burst on rare drops; light camera shake on big hits. No source documents exact parameters.

### Lighting
- `Lighting.Technology`: Voxel (4x4x4 light grid), ShadowMap (crisp sun shadows), Future (most advanced), Compatibility (deprecated; mimic with Voxel plus a Retro ColorGradingEffect). Technology is now superseded by `LightingStyle` and `PrioritizeLightingQuality`. The docs give no performance numbers ([Technology enum](https://create.roblox.com/docs/reference/engine/enums/Technology.md)).
- Voxel or ShadowMap over Future for low-end phones is DevForum consensus, unverified.

### Audio rules
- Since March 22, 2022, user-uploaded audio is private; only Roblox-licensed or creator-owned audio is public ([Pro Game Guides, 2022](https://progameguides.com/roblox/roblox-to-private-millions-of-user-created-sounds-within-its-audio-database/)).
- Audio is Restricted (owner plus granted experiences) or Open Use (irreversible). Grant access in Creator Dashboard: Development Items > Audio > Permissions > Experiences; game-level grants cannot be revoked ([Asset privacy](https://create.roblox.com/docs/projects/assets/privacy)).

### Thumbnails
16:9 at 1920x1080; up to 10 images/videos; personalization images under 3 MB; 3 free video uploads per month, authentic gameplay, no voice-over; personalization needs 2+ (2-5 recommended) and averaged +8.5% qualified play-through lift, up to +50% ([Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)).

## Grow A Golem today

- Every model built from parts in code; procedural Motor6D animation; low-poly. Fits the genre's tolerance for simple art.
- Server-side lighting setup in `WorldService` with per-zone color grading (`Config` `controlLighting`); Technology choice not set in code (check in Studio).
- Feedback: hit flashes, damage numbers, debris, boss HP bar, artifact reveal card, level-up banner.
- Audio: built-in client sounds (`rbxasset://sounds/...`) re-pitched via `Config.SoundEffects`; `Config.Sounds` moment ids (artifact, levelUp, grow) are 0, so they fall back to the re-pitched effects. No music found. No volume settings found.
- No shared rarity color table with symbols found; no ReducedMotion gating.
- No thumbnails or icon yet (#16).
- UI surfaces use five original materials (wood, stone, metal, studs, crystal), drawn in code with optional tiling textures in `assets/ui-textures/`; see [ui-materials.md](ui-materials.md).

## Gaps worth closing

1. **P1:** One rarity table (color + symbol + name) in Config, used by the artifact reveal card, inventory and Shop (`images/rarity-colors.png`).
2. **P1:** ReducedMotion gating for shake, pop and slide effects.
3. **P1 (#16):** Upload original SFX for the three big moments and a looping music track; grant universe permissions; add SFX/music volume sliders.
4. **P1 (#16):** 3-5 bright, golem-forward thumbnails at 1920x1080 plus an icon; rotate per update.
5. **P2 (#16):** Per-tier forge visuals (material and color per tier) so power is visible.
6. **P2:** Pick Voxel or ShadowMap after measuring on a low-end phone (#9).

## Sources

All accessed 2026-10.
- Wikipedia, Grow a Garden: https://en.wikipedia.org/wiki/Grow_a_Garden
- Wikipedia, Steal a Brainrot: https://en.wikipedia.org/wiki/Steal_a_Brainrot
- Pet Simulator Wiki, Ranks (PS99): https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99)
- Roblox Creator Docs, Accessibility: https://create.roblox.com/docs/en-us/production/publishing/accessibility.md
- Roblox Creator Docs, Technology enum: https://create.roblox.com/docs/reference/engine/enums/Technology.md
- Roblox Creator Docs, Asset privacy: https://create.roblox.com/docs/projects/assets/privacy
- Roblox Creator Docs, Thumbnails: https://create.roblox.com/docs/production/publishing/thumbnails
- Roblox Creator Docs, Content maturity: https://create.roblox.com/docs/production/promotion/content-maturity
- Roblox Creator Docs, Design for performance: https://create.roblox.com/docs/en-us/performance-optimization/design
- Pro Game Guides, 2022 audio privacy change: https://progameguides.com/roblox/roblox-to-private-millions-of-user-created-sounds-within-its-audio-database/
- DevForum, audio privacy announcement (returned empty when fetched): https://devforum.roblox.com/t/1701697
