# UI/UX, Audio/Visual Style, and Performance/Mobile Standards in Top Roblox Games (2025-2026)

Research note: about 15 tool calls. Several create.roblox.com doc pages could not be fetched (client_error), and fetched pages often had no numbers. Many genre-convention claims (left-side button column, chunky outlined fonts, rarity colors) could NOT be confirmed against a primary source in this pass and are listed under Inferences/Gaps. Do not present them as sourced facts.

## HUD layout conventions in top simulator/idle/tycoon/pet games

### Takeaway
The 2025 hit games (Grow a Garden, Steal a Brainrot, 99 Nights) run very simple, session-light loops: buy, place, earn passively, rebirth, plus timed restocks and events. Their UI follows a shared "simulator" style that is now sold as ready-made UI packs. No source I found documents exact HUD placement, so treat the layout details as convention from experience, not citable fact.

### Cited Findings
- Grow a Garden loop: start with an empty plot and Sheckles, buy seeds, harvest for currency, buy rarer seeds. Crops grow while the player is offline. Seed shop stock rotates, weekly exclusive items need the player online to claim (a retention driver), pets come from loot boxes, and Robux skips waiting. — [Wikipedia: Grow a Garden](https://en.wikipedia.org/wiki/Grow_a_Garden)
- Press on Grow a Garden's look: Kotaku said it looks more like a prototype than a finished product; PCGamesN called it "a pretty standard AFK game"; Game File called it this generation's FarmVille, citing its simplicity. This suggests polish was not what drove its success. — [Wikipedia: Grow a Garden](https://en.wikipedia.org/wiki/Grow_a_Garden)
- Grow a Garden CCU history: about 5M (May 18, 2025), 11.7M (May 31), 21.3M (June 21, Summer Update), 22.3M+ (Aug 23, mock "admin war"). It was reportedly built in about 3 days by a 16-year-old. — [Wikipedia: Grow a Garden](https://en.wikipedia.org/wiki/Grow_a_Garden)
- Steal a Brainrot loop: buy Brainrots from a conveyor belt, they generate passive income, players can steal them from others, a base button raises a temporary shield, traps can be bought with currency or Robux, and "Rebirth" resets progress for better stats. Frequent "admin abuse" events give out exclusives. Peaks: 20M (Aug 2025), 24M (Sept 13), 25.4M (Oct 2025). It won Best Creative Direction at the 2025 Roblox Innovation Awards. PC Gamer called the events a "sensory overload." — [Wikipedia: Steal a Brainrot](https://en.wikipedia.org/wiki/Steal_a_Brainrot)
- Top 2025 games by visits: Steal a Brainrot had 26.4B visits in Q3; Grow a Garden had 12.3B in Q2 and was out of the top 10 by December; 99 Nights in the Forest passed 10B within months. Brookhaven and Blox Fruits were top 10 every month. Concentration grew: the #1 title's share of top-10 visits went from 22% (Q1) to 43% (Q4). — [Newzoo via GameDevReports](https://gamedevreports.substack.com/p/newzoo-top-roblox-games-in-2025)
- Pet Simulator 99 Ranks: a quests panel sits at the side of the screen, and each rank has a reward path (reward, stars required, rarity, quantity) that unlocks pet-equip, egg and enchant slots. PS99 rarity tiers named on the wiki: Basic, Rare, Epic, Legendary, Mythical, Exotic, Divine, Superior, Celestial. The page lists no colors. — [Pet Simulator Wiki: Ranks (PS99)](https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99))
- A commercial market for "Grow a Garden style" and "cartoony simulator" UI kits exists, which shows the look is now a reusable template: [BuiltByBit UI PACK Grow a Garden Style](https://builtbybit.com/resources/ui-pack-grow-a-garden-style.102616/), [itch.io GAG UI pack](https://adrianart.itch.io/gag-ui-pack), [BuiltByBit Modern Cartoon Simulator UI](https://builtbybit.com/resources/modern-cartoon-simulator-ui.109159/), [BuiltByBit Cartoony UI Kit 25+ Frames](https://builtbybit.com/resources/cartoony-ui-kit-25-frames.117327/), [itch.io Simulator UI Buttons Pack](https://ryvion-studios.itch.io/simulator-ui-buttons-pack), [itch.io Roblox Simulator Store UI](https://ryvion-studios.itch.io/roblox-simulator-store-ui). Pages not fetched; listed by title only.
- Roblox docs on mobile: keep frequently used buttons in easy thumb reach near the bottom corners, but don't block the default controls there. Show only vital info during play. Use context UI such as ProximityPrompts instead of always-visible buttons. — [Roblox Docs: Cross-platform design](https://create.roblox.com/docs/ui/cross-platform-design)
- Roblox docs: on small screens, move less important buttons into a collapsible menu. — [Roblox Docs: Adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design.md)

### Inferences
- These conventions are common across PS99, Bee Swarm, Blox Fruits and Adopt Me, but are unverified here:
  - Currency counters stack at the left-center or bottom-left (PS99, Bee Swarm) or top-center.
  - A vertical column of square icon buttons (Shop, Pets/Inventory, Rebirth, Quests, Settings) sits on the left edge, near the vertical middle.
  - A red circle badge with a white number or "!" marks unclaimed rewards.
  - Fonts are heavy rounded types (Fredoka One, Luckiest Guy, Gotham Black/Builder Sans Bold) with a thick dark UIStroke outline.
  - Panels have rounded corners (UICorner), bright saturated gradients, and a drop shadow.
  - Large numbers use suffixes (1.2K, 3.4M, 5.6B, then T, Qd, Qn).
  - Mobile is the main platform, and the doc guidance above (bottom-corner reach, collapsible menus) is consistent with these conventions.
- For a 9-15 idle auto-battler: Grow a Garden and Steal a Brainrot show that a clear loop (passive income, timed restocks, rebirth, events) matters more than visual polish. A simple, legible HUD is enough.

### Gaps
- I found no primary-source teardown of the HUD layout of any named game (PS99, Bee Swarm, Blox Fruits, Adopt Me, Anime Defenders, Fisch, 99 Nights, TDS). The game Fandom wikis could not be found via search in this pass.
- No source found for number-formatting conventions, font choices, or button color norms.

## Roblox official UI guidance (safe areas, touch targets, scaling, cross-platform, accessibility)

### Takeaway
Roblox's official guidance on safe areas is concrete: use ScreenGui.ScreenInsets = CoreUISafeInsets for interactive UI. Its guidance on layout, gamepad and contrast is qualitative. The fetched pages give no touch-target pixel minimum or contrast ratio. Accessibility uses engine settings players control: PreferredTextSize, PreferredTransparency and ReducedMotionEnabled.

### Cited Findings
- ScreenInsets enum:
  - None: content can go under notches; use only for non-interactive backgrounds.
  - DeviceSafeInsets: avoids hardware cutouts but not Roblox core UI.
  - CoreUISafeInsets: also avoids Roblox core UI; recommended for buttons and important elements.
  - TopbarSafeInsets: the dynamic top-bar area; read its bounds from GuiService.TopbarInset.
  - — [Roblox Docs: ScreenInsets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets.md)
- Scale is a fraction of the parent size, Offset is pixels, and the two are added together in UDim2. In Studio, typing 0.5 sets 50% scale and typing 20 sets 20 px offset. AnchorPoint sets the origin. — [Roblox Docs: Position and size](https://create.roblox.com/docs/en-us/ui/position-and-size.md); [Cross-platform design](https://create.roblox.com/docs/ui/cross-platform-design)
- Reach differs by device: a button 40% down from the top is reachable on a phone but awkward on a tablet. Place custom buttons relative to the default jump button. — [Roblox Docs: Cross-platform design](https://create.roblox.com/docs/ui/cross-platform-design)
- Adaptive design guidance:
  - Every action should be triggerable by gamepad or D-pad, and controls should be focusable for directional navigation.
  - Prompts should change with the active input ("Press A", tap, key).
  - Support portrait and landscape if the game allows both, and collapse panels on narrow screens.
  - Use AutomaticSize and TextWrapped.
  - Avoid thin or decorative fonts and test on real devices.
  - Use enough contrast to read under changing in-game lighting (no ratio given).
  - — [Roblox Docs: Adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design.md)
- Accessibility:
  - Over 26% of people have a disability, and over 5% have some color blindness.
  - Pair color with symbols so meaning survives in grayscale.
  - GuiService.PreferredTextSize defaults to Medium, with Large, Larger and Largest options. TextScaled ignores it, and UITextSizeConstraint clamps it; AutomaticSize and TextWrapped adapt to it.
  - Multiply each element's BackgroundTransparency by GuiService.PreferredTransparency (1 by default, 0 for fully opaque).
  - When GuiService.ReducedMotionEnabled is on, replace the 0.75 s motion tween in the doc's example with an instant snap or a fade.
  - Don't signal events by sound alone, and give separate volume controls for SFX, music and speech.
  - — [Roblox Docs: Accessibility](https://create.roblox.com/docs/en-us/production/publishing/accessibility.md)
- A community guide (not official) uses UIAspectRatioConstraint (FitWithinMaxSize, DominantAxis Width), GuiService:GetGuiInset() plus a 10 px padding, and breakpoints at 600 px (mobile) and 1200 px (tablet). — [playbooks.com game-dev-skills ui-ux](https://playbooks.com/skills/taozhuo/game-dev-skills/ui-ux)

### Inferences
- Practical standard:
  - Use Scale for position and size.
  - Add UIAspectRatioConstraint on square buttons and panels so they don't stretch.
  - Use UIScale or UISizeConstraint to cap size on large screens.
  - Set CoreUISafeInsets on every interactive ScreenGui.
  - Avoid TextScaled on body text if you want to respect PreferredTextSize.
- The touch-target minimum commonly quoted on DevForum (about 44-48 px, from Apple and Google HIG) is not confirmed by a Roblox source in this pass.

### Gaps
- Pages that failed to load: create.roblox.com/docs/ui/mobile-ui and the cross-platform projects page. Touch-target pixel minimums, VR UI guidance and console 10-foot UI specifics remain unsourced.

## Juice/feedback and rarity color conventions

### Takeaway
The only sourced point here is from Roblox's accessibility guidance: tweens should respect ReducedMotionEnabled, and color-coded rarity should be paired with symbols or labels. The rarity color ladder itself is industry convention, not a Roblox standard, and individual games use different tier names.

### Cited Findings
- Respect ReducedMotionEnabled: snap or fade instead of moving (the doc's example tween is 0.75 s). Pair colors with symbols for color-blind players. — [Roblox Docs: Accessibility](https://create.roblox.com/docs/en-us/production/publishing/accessibility.md)
- Tier names vary by game. PS99 uses Basic, Rare, Epic, Legendary, Mythical, Exotic, Divine, Superior, Celestial. — [Pet Simulator Wiki](https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99))
- Steal a Brainrot's events were described as "sensory overload" (PC Gamer, via Wikipedia). Heavy juice is the norm in hit games. — [Wikipedia: Steal a Brainrot](https://en.wikipedia.org/wiki/Steal_a_Brainrot)
- Example of an older DevForum thread on naming rarity tiers: [DevForum: Need tier list names](https://devforum.roblox.com/t/need-tier-list-names/761008) (not fetched).

### Inferences
- Common convention (unsourced in this pass, widely used by Fortnite and most Roblox simulators): Common gray/white, Uncommon green, Rare blue, Epic purple, Legendary gold/orange, Mythic red/pink. Above that, rainbow or animated gradient tiers (Secret, Divine, Exotic) are common in Roblox pet games.
- Typical juice: TweenService button scale-bounce on hover/press (about 1.05-1.1x, 0.1 s), a click SFX on every button, a "pop" scale-in for reward popups, floating "+123" damage or currency numbers, a particle burst on hatch or rare drops, and light camera shake on big events. Gate all of these behind ReducedMotionEnabled.

### Gaps
- No Roblox or press source was found that documents per-game rarity colors or juice parameters. The Fortnite wiki rarity page appeared in search but was not fetched.

## Audio/visual style (art, lighting, music/SFX, audio privacy, thumbnails)

### Takeaway
Hit games are visually simple: Grow a Garden uses studded, old-school textures and Steal a Brainrot uses voxel meme characters. Audio must come from your own uploads or Roblox's licensed library, because user audio has been private by default since March 2022. Thumbnails should be 16:9 at 1920×1080, and you should keep 2-5 active so personalization can test them (+8.5% average play-through lift).

### Cited Findings
- Grow a Garden art uses studded textures that recall old-school Roblox, with a classical soundtrack (including Mozart's Rondo Alla Turca, public domain). — [Wikipedia: Grow a Garden](https://en.wikipedia.org/wiki/Grow_a_Garden)
- Steal a Brainrot characters are voxel models based on the 2025 "Italian brainrot" memes. — [Wikipedia: Steal a Brainrot](https://en.wikipedia.org/wiki/Steal_a_Brainrot)
- Lighting.Technology values:
  - Voxel: a 4×4×4 voxel light grid.
  - ShadowMap: crisp sun shadows.
  - Future: the most advanced lighting.
  - Compatibility: deprecated; to mimic it, use Voxel plus a ColorGradingEffect with the Retro preset.
  - Technology is now superseded by LightingStyle and PrioritizeLightingQuality.
  - The page gives no performance numbers.
  - — [Roblox Docs: Technology enum](https://create.roblox.com/docs/reference/engine/enums/Technology.md)
- 2022 audio update: from March 22, 2022, all user-uploaded audio became private. Only audio created, uploaded or approved by Roblox licensing stayed public, and song IDs were replaced by Roblox's licensed catalog. — [Pro Game Guides](https://progameguides.com/roblox/roblox-to-private-millions-of-user-created-sounds-within-its-audio-database/) (older, 2022). Original announcement thread: [DevForum: Upcoming Changes to Asset Privacy for Audio](https://devforum.roblox.com/t/1701697) (returned empty when fetched).
- Current permission model: audio is Restricted (only the owner and experiences they grant) or Open Use (irreversible).
  - To grant an experience access: Creator Dashboard, then Development Items, then Audio, then Permissions, then Experiences, then add the universe ID.
  - A game-level grant cannot be revoked.
  - Scripts and templates need game-level permission, or the audio stays silent at runtime.
  - The Asset Privacy setting does not apply to audio.
  - — [Roblox Docs: Asset privacy](https://create.roblox.com/docs/projects/assets/privacy)
- Thumbnails:
  - Format: 16:9, ideally 1920×1080 (other ratios are stretched), up to 10 images or videos per page, under 3 MB for personalization images.
  - Video: 3 free video uploads per month. Videos must show authentic gameplay, with no voice-over or lyric music. Console and VR don't show video.
  - Content: keep key elements off the bottom edge (player-count overlay), avoid promo claims like "50% off" and heavy text, and add alt text.
  - Personalization: needs 2+ thumbnails (2-5 recommended) and gave a +8.5% average lift in qualified play-through, up to +50%.
  - — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)

### Inferences
- A low-poly idle auto-battler should:
  - Use built-in materials and flat colors (cheap; see Performance).
  - Use Voxel or ShadowMap lighting rather than Future for low-end mobile. This is unconfirmed by docs; it is the common DevForum view.
  - Upload its own SFX or use the Creator Store licensed library.
  - Ship 3-5 bright, character-forward thumbnails and rotate them with each update.

### Gaps
- Not found: the Roblox experience-icon guidance page (failed to load), a length threshold for public audio (the "6 seconds" claim was not confirmed), and documented lighting performance cost per technology.

## Performance/mobile standards

### Takeaway
About 80% of Roblox DAU played on mobile in 2024. Roblox's own docs say to pick a low-end baseline device, stay within a 16.67 ms frame, and (in their example) keep draw calls under about 1,000 and triangles under about 1M. They also recommend instance streaming for most places and built-in materials over custom textures. Remote rate limits are not officially documented, and the community treats about 20 calls/s per remote as safe.

### Cited Findings
- About 80% of Roblox DAU (82.9M average in 2024) played on mobile. Mobile app stores accounted for 46% of Robux revenue (Roblox annual report, reported April 23, 2025). — [PocketGamer.biz](https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue)
- Platform totals for 2025: 126.5M average DAU (+53%), 123.8B hours (+69%), $4.9B revenue. — [Newzoo via GameDevReports](https://gamedevreports.substack.com/p/newzoo-top-roblox-games-in-2025)
- Design for performance — [Roblox Docs: Design for performance](https://create.roblox.com/docs/en-us/performance-optimization/design):
  - Budget: 16.67 ms per frame at 60 FPS. The baseline low-end example is under 1,000 draw calls and under 1,000,000 triangles.
  - Work spreading: 100 ms of work every frame caps the game at 10 FPS; splitting it into about 5 ms slices keeps 60 FPS.
  - Test device: pick a baseline low-end device and test on it throughout. Studio's emulator is inaccurate for memory because it runs client and server together.
  - Streaming: instance streaming "improves join times, reduces memory footprint, and increases frame rate" and is recommended for most places.
  - Assets: built-in materials use far less memory than custom textures. Reuse meshes and textures (via packages) to cut draw calls. Keep Transparency at 0 or 1 to avoid overdraw.
  - Scripts and storage: prefer event-driven code over per-frame loops, disconnect unused connections, and keep client-unneeded assets in ServerStorage (the client loads all of ReplicatedStorage).
  - Tools: Developer Console (F9) for memory, and Shift+F2 render stats for draw calls and triangles.
- Performance optimization hub: [Roblox Docs: Performance optimization](https://create.roblox.com/docs/performance-optimization) (not fetched). Community real-world guide: [DevForum: Real world building and scripting optimization](https://devforum.roblox.com/t/3127146) (not fetched).
- Remote limits (community claims, no staff source):
  - Firing about 20 times/s per remote is "relatively safe."
  - UnreliableRemoteEvent payload is capped (stated as 1000 KB; verify, since this may be bytes, not KB).
  - Ordered remotes queue and can drop events when the queue is exhausted.
  - A claimed "15 calls/s" limit is disputed.
  - — [DevForum: Remote event limitations](https://devforum.roblox.com/t/remote-event-limitations/3882204)

### Inferences
- For an idle auto-battler on mobile:
  - Simulate combat server-side in batched ticks.
  - Send compact state diffs a few times per second, not per-hit remotes, and render hit effects client-side.
  - Use pooled MeshParts with shared MeshIds and textures.
  - Enable StreamingEnabled.
  - Cap visible units and particles on low-end devices.
- The DevForum consensus that MeshParts beat complex unions (CSG) on memory and collision cost is widely repeated but was not verified in this pass.

### Gaps
- No official numbers were found for memory budget per device, recommended part or instance counts, an official remote bandwidth cap (the commonly cited ~50 KB/s was not found), or MicroProfiler usage. The MicroProfiler docs were not fetched.

## Visual references (URLs showing top-game UIs)

### Takeaway
I verified only a few reference pages, and I fetched none of them as images. The list below separates sources I verified from candidate URLs that need a manual check. Fandom game wikis did not appear in search results this pass.

### Cited Findings
Verified (fetched or seen in search):
1. [Pet Simulator Wiki: Ranks (PS99)](https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99)): rank reward-path tables, quest panel description, rarity tier names.
2. [Pet Simulator Wiki: Gamepasses (PS99)](https://pet-simulator.fandom.com/wiki/Gamepasses_(Pet_Simulator_99)): PS99 gamepass list, likely with shop icons (not fetched).
3. [Wikipedia: Grow a Garden](https://en.wikipedia.org/wiki/Grow_a_Garden): infobox image of the game, loop and CCU history.
4. [Wikipedia: Steal a Brainrot](https://en.wikipedia.org/wiki/Steal_a_Brainrot): infobox image, loop, CCU history.
5. [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails): thumbnail spec and good/bad examples.
6. [Roblox Docs: Cross-platform design](https://create.roblox.com/docs/ui/cross-platform-design): mobile reserved zones and thumb reach.
7. [Roblox Docs: Adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design.md): Touch/Gamepad/Mouse and Small/Medium/Large layout sections (likely illustrated).
8. [Roblox Docs: Create HUD meters](https://create.roblox.com/docs/en-us/tutorials/use-case-tutorials/ui/create-hud-meters.md): tutorial for HUD bars with safe-area handling (not fetched).
9. [Roblox Docs: Accessibility](https://create.roblox.com/docs/en-us/production/publishing/accessibility.md): text size, transparency and reduced-motion examples.
10. [BuiltByBit: UI PACK Grow a Garden Style](https://builtbybit.com/resources/ui-pack-grow-a-garden-style.102616/): sale page showing a GAG-style UI kit (shop panels, buttons).
11. [itch.io: GAG UI pack](https://adrianart.itch.io/gag-ui-pack): another Grow-a-Garden-style UI kit preview.
12. [BuiltByBit: Modern Cartoon Simulator UI](https://builtbybit.com/resources/modern-cartoon-simulator-ui.109159/): cartoony simulator HUD and shop mockups.
13. [BuiltByBit: Cartoony UI Kit 25+ Frames](https://builtbybit.com/resources/cartoony-ui-kit-25-frames.117327/): over 25 cartoon frames (panels, popups).
14. [BuiltByBit: Cartoony UI Pack Pro+](https://builtbybit.com/resources/cartoony-ui-pack-pro-ui-system.107727/): a full cartoony UI system.
15. [itch.io: Simulator UI Buttons Pack](https://ryvion-studios.itch.io/simulator-ui-buttons-pack): chunky outlined simulator buttons.
16. [itch.io: Roblox Simulator Store UI](https://ryvion-studios.itch.io/roblox-simulator-store-ui): simulator shop panel.
17. [itch.io: Free Cartoon Store UI (KW Studio)](https://kwstudioorg.itch.io/free-roblox-store-interface-custom-cartoon-ui-system-scripted): free scripted cartoony shop UI.
18. [DevForum: Feedback on my Simulator UI?](https://devforum.roblox.com/t/feedback-on-my-simulator-ui/1553479): simulator HUD screenshot with critique (older, about 2021).
19. [DevForum: Learning UI design #2](https://devforum.roblox.com/t/learning-ui-design-2/2288030): UI design practice thread with images (2023).
20. [DevForum: Feedback for my UI](https://devforum.roblox.com/t/feedback-for-my-ui/2737410): UI critique thread (about 2023-24).
21. [Grow a Garden seed/gear shop guide (Deltia's Gaming)](https://deltiasgaming.com/?p=207402): article on seed shop and gear shop stock, likely with screenshots.
22. [Where to find the Gear Shop (esports.gg)](https://esports.gg/news/roblox/where-to-find-the-gear-shop-in-grow-a-garden): GAG gear shop location, with screenshots.

### Inferences
- Candidate official game pages (URLs from memory, NOT verified this pass; each page shows the publisher's thumbnails, which typically show the HUD):
  - Grow a Garden: https://www.roblox.com/games/126884695634066
  - Steal a Brainrot: https://www.roblox.com/games/109983668079237
  - Blox Fruits: https://www.roblox.com/games/2753915549
  - Adopt Me: https://www.roblox.com/games/920587237
  - Pet Simulator 99: https://www.roblox.com/games/8737899170
  - Bee Swarm Simulator: https://www.roblox.com/games/1537690962
  - Tower Defense Simulator: https://www.roblox.com/games/3260590327
  - 99 Nights in the Forest: https://www.roblox.com/games/79546208627805
- The report writer should flag these as unverified.

### Gaps
- Not reached: Fandom wiki pages with UI screenshots for Bee Swarm, Blox Fruits, Adopt Me, Anime Defenders/Adventures, Fisch, 99 Nights and TDS. Search returned spam and mirrors instead. The target of 20-30 verified visual references was not fully met with fetched pages.
