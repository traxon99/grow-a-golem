# Visual references

Last updated: 2026-10-27. We do not store other games' screenshots here. These are links to pages that show notable game UIs or official UI guidance, plus our own original wireframes.

Status key:
- **Verified**: the page was fetched or seen in search results during research (2026-10). Contents of image-heavy pages were not inspected as images.
- **Title only**: found in search; page listed by title, not fetched.
- **From memory**: URL recalled, not checked. Confirm before relying on it.

## Official Roblox guidance pages

| Link | What it shows | Status |
|---|---|---|
| [Roblox Docs: Cross-platform design](https://create.roblox.com/docs/ui/cross-platform-design) | Mobile reserved zones (joystick, jump) and thumb reach | Verified |
| [Roblox Docs: Adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design.md) | Touch/gamepad/mouse and small/medium/large layout sections | Verified |
| [Roblox Docs: Accessibility](https://create.roblox.com/docs/en-us/production/publishing/accessibility.md) | Text size, transparency and reduced-motion examples | Verified |
| [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails) | Thumbnail spec with good/bad examples | Verified |
| [Roblox Docs: Create HUD meters](https://create.roblox.com/docs/en-us/tutorials/use-case-tutorials/ui/create-hud-meters.md) | Tutorial for HUD bars with safe-area handling | Title only |

## Game pages and wikis

| Link | What it shows | Status |
|---|---|---|
| [Pet Simulator Wiki: Ranks (PS99)](https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99)) | Rank reward-path tables, side quest panel, rarity tier names | Verified |
| [Pet Simulator Wiki: Gamepasses (PS99)](https://pet-simulator.fandom.com/wiki/Gamepasses_(Pet_Simulator_99)) | PS99 pass list, likely with shop icons | Verified (images not checked) |
| [Blox Fruits Wiki: Shop](https://blox-fruits.fandom.com/wiki/Shop) | Blox Fruits pass and product shop list | Verified |
| [Wikipedia: Grow a Garden](https://en.wikipedia.org/wiki/Grow_a_Garden) | Infobox image of the game, loop and CCU history | Verified |
| [Wikipedia: Steal a Brainrot](https://en.wikipedia.org/wiki/Steal_a_Brainrot) | Infobox image, loop and CCU history | Verified |
| [Deltia's Gaming: Grow a Garden seed/gear shop](https://deltiasgaming.com/?p=207402) | Seed and gear shop stock article, likely with screenshots | Title only |
| [esports.gg: Grow a Garden Gear Shop](https://esports.gg/news/roblox/where-to-find-the-gear-shop-in-grow-a-garden) | Gear shop location, with screenshots | Title only |

## UI kits showing the "simulator" look

These are commercial or free kit pages; they illustrate the cartoony simulator style. Do not copy their art.

| Link | What it shows | Status |
|---|---|---|
| [BuiltByBit: UI PACK Grow a Garden Style](https://builtbybit.com/resources/ui-pack-grow-a-garden-style.102616/) | GAG-style shop panels and buttons | Title only |
| [itch.io: GAG UI pack](https://adrianart.itch.io/gag-ui-pack) | Another Grow a Garden-style kit preview | Title only |
| [BuiltByBit: Modern Cartoon Simulator UI](https://builtbybit.com/resources/modern-cartoon-simulator-ui.109159/) | Cartoony simulator HUD and shop mockups | Title only |
| [BuiltByBit: Cartoony UI Kit 25+ Frames](https://builtbybit.com/resources/cartoony-ui-kit-25-frames.117327/) | 25+ cartoon panels and popups | Title only |
| [BuiltByBit: Cartoony UI Pack Pro+](https://builtbybit.com/resources/cartoony-ui-pack-pro-ui-system.107727/) | Full cartoony UI system | Title only |
| [itch.io: Simulator UI Buttons Pack](https://ryvion-studios.itch.io/simulator-ui-buttons-pack) | Chunky outlined simulator buttons | Title only |
| [itch.io: Roblox Simulator Store UI](https://ryvion-studios.itch.io/roblox-simulator-store-ui) | Simulator shop panel | Title only |
| [itch.io: Free Cartoon Store UI (KW Studio)](https://kwstudioorg.itch.io/free-roblox-store-interface-custom-cartoon-ui-system-scripted) | Free scripted cartoony shop UI | Title only |

## DevForum critique threads

| Link | What it shows | Status |
|---|---|---|
| [Feedback on my Simulator UI?](https://devforum.roblox.com/t/feedback-on-my-simulator-ui/1553479) | Simulator HUD screenshot with critique (about 2021) | Title only |
| [Learning UI design #2](https://devforum.roblox.com/t/learning-ui-design-2/2288030) | UI practice thread with images (2023) | Title only |
| [Feedback for my UI](https://devforum.roblox.com/t/feedback-for-my-ui/2737410) | UI critique thread (about 2023-24) | Title only |

## Official game pages (from memory, unverified)

Each Roblox game page shows the publisher's thumbnails, which usually show the HUD. These URLs were recalled, not checked.

| Game | URL |
|---|---|
| Grow a Garden | https://www.roblox.com/games/126884695634066 |
| Steal a Brainrot | https://www.roblox.com/games/109983668079237 |
| Blox Fruits | https://www.roblox.com/games/2753915549 |
| Adopt Me! | https://www.roblox.com/games/920587237 |
| Pet Simulator 99 | https://www.roblox.com/games/8737899170 |
| Bee Swarm Simulator | https://www.roblox.com/games/1537690962 |
| Tower Defense Simulator | https://www.roblox.com/games/3260590327 |
| 99 Nights in the Forest | https://www.roblox.com/games/79546208627805 |

Known gap: no verified screenshot pages were reached for Bee Swarm, Adopt Me, Anime Defenders, Fisch, 99 Nights or TDS UIs.

## Our wireframes

Original wireframes drawn for Grow A Golem, stored in `docs/reference/images/`. They are rendered from the HTML sources in `images/src/`: edit the HTML, then run `node docs/reference/images/src/render.js` (needs Playwright) to regenerate the PNGs. Sticky notes on each image explain the rule it shows.

| File | What it shows | Related doc |
|---|---|---|
| [images/hud-layout.png](images/hud-layout.png) | Standard simulator HUD adapted for Grow A Golem: currency top-left, menu column left, spell buttons bottom-right, goal tracker top-center | [ui-ux.md](ui-ux.md) |
| [images/shop-layout.png](images/shop-layout.png) | Shop with game passes, products, odds disclosure, and the Robux price on every button | [monetization.md](monetization.md), [safety-compliance.md](safety-compliance.md) |
| [images/reward-popup.png](images/reward-popup.png) | Reward/artifact reveal card with rarity color and real odds | [art-audio.md](art-audio.md), [progression.md](progression.md) |
| [images/mobile-safe-areas.png](images/mobile-safe-areas.png) | Phone screen with safe insets, thumb zones, and default joystick/jump areas to keep clear | [ui-ux.md](ui-ux.md), [performance-mobile.md](performance-mobile.md) |
| [images/rarity-colors.png](images/rarity-colors.png) | Our rarity color ladder with symbols for color-blind players | [art-audio.md](art-audio.md) |
| [images/ui-materials.png](images/ui-materials.png) | Our five UI materials (wood, stone, metal, studs, crystal), code-only and with textures, with worst-case text samples | [ui-materials.md](ui-materials.md) |

## Grow A Golem today

- #109: The existing HUD and menus now consume `Icons.create`: XP/minerals/spells, all 13 tabs, the current window header, close, travel guide/locks, quests and event points/reward status. Icons retain adjacent words and zero-ID text fallbacks. No new animation, remote, rarity assignment or purchase behavior is added. Approved sprite uploads still require the owner (#83); broader menu restyles remain separate.

- [Original mystical icon proof](images/ui-icons.png): 37 symbols at 128 px and 32 px, with grayscale checks, from issue #83. Rebuild from `assets/ui-icons/build.cjs`; the icon inventory maps each asset to its consuming issue. Existing-screen integration is complete in #109; owner uploads remain pending.

## Sources

All accessed 2026-10. The links in the tables above are the sources.
