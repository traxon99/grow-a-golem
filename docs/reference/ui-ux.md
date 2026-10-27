# UI/UX

Last updated: 2026-10-27. See also [performance-mobile.md](performance-mobile.md), [art-audio.md](art-audio.md) and the wireframes in [visual-references.md](visual-references.md#our-wireframes).

![HUD layout wireframe](images/hud-layout.png)

![Mobile safe areas](images/mobile-safe-areas.png)

## Rules for agents

1. **Set `ScreenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets` on every ScreenGui with buttons or important info.** Use `None` only for non-interactive backgrounds ([ScreenInsets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets.md)).
2. **Position and size with Scale,** add `UIAspectRatioConstraint` to square buttons and icons, and cap size on big screens with `UISizeConstraint`/`UIScale` (inference from [Position and size](https://create.roblox.com/docs/en-us/ui/position-and-size.md)).
3. **Keep the default mobile joystick (bottom-left) and jump button (bottom-right) clear.** Place custom touch buttons relative to the jump button, in thumb reach of the bottom corners ([Cross-platform design](https://create.roblox.com/docs/ui/cross-platform-design)).
4. **Do not use `TextScaled` for body text;** it ignores the player's `GuiService.PreferredTextSize`. Use fixed TextSize with `TextWrapped` and `AutomaticSize`, clamped by `UITextSizeConstraint` where needed ([Accessibility](https://create.roblox.com/docs/en-us/production/publishing/accessibility.md)).
5. **Respect `GuiService.ReducedMotionEnabled`:** replace slides, bounces and shakes with an instant snap or fade (same source).
6. **Multiply panel `BackgroundTransparency` by `GuiService.PreferredTransparency`** (same source).
7. **Never signal by color alone.** Rarity and status carry a symbol or label too (over 5% of people have some color blindness, same source).
8. **Every action works with touch, mouse/keyboard and gamepad;** prompts change with the active input ("Press A", tap, Q) ([Adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design.md)).
9. **Show only vital info during play;** move secondary buttons into a collapsible menu on small screens; prefer ProximityPrompts for context actions ([Cross-platform design](https://create.roblox.com/docs/ui/cross-platform-design); [Adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design.md)).
10. **Abbreviate large numbers** with one shared helper (1.2K, 3.4M, 5.6B, T...) (common practice, unverified).
11. **Every purchase button shows its Robux price** (see [safety-compliance.md](safety-compliance.md)).
12. Touch targets: aim for at least about 44-48 px (Apple/Google HIG figure quoted on DevForum; no Roblox source, unverified).

## What top games do

### HUD layout (convention, mostly unverified)
No primary source documents exact HUD placement for any named game. The following is common practice seen in PS99, Bee Swarm, Blox Fruits and Adopt Me (unverified):
- Currency counters stacked at left-center/bottom-left or top-center.
- A vertical column of square icon buttons (Shop, Inventory, Rebirth, Quests, Settings) on the left edge near vertical middle.
- A red badge with a number or "!" on buttons with unclaimed rewards.
- Heavy rounded fonts with a thick dark `UIStroke` outline; rounded panels (`UICorner`), saturated gradients, drop shadows.

Sourced points:
- PS99 shows a quests panel at the side of the screen, and each rank has a reward path ([PS99 wiki: Ranks](https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99))).
- The "Grow a Garden style" and "cartoony simulator" look is sold as ready-made UI kits, which shows it is a reusable template (see [visual-references.md](visual-references.md)).
- Grow a Garden was called prototype-like by Kotaku and still hit about 22M CCU, which suggests a clear loop beats polish ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)).

### Roblox official guidance
- **ScreenInsets:** `None` (under notches), `DeviceSafeInsets` (avoids cutouts only), `CoreUISafeInsets` (also avoids Roblox core UI; recommended), `TopbarSafeInsets` (read `GuiService.TopbarInset`) ([ScreenInsets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets.md)).
- **Reach varies by device:** a button 40% down the screen is reachable on a phone, awkward on a tablet ([Cross-platform design](https://create.roblox.com/docs/ui/cross-platform-design)).
- **Adaptive:** gamepad-focusable controls, portrait and landscape if allowed, collapse panels on narrow screens, avoid thin or decorative fonts, enough contrast for changing lighting (no ratio given), test on real devices ([Adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design.md)).
- **Accessibility:** PreferredTextSize (Medium default up to Largest), PreferredTransparency, ReducedMotionEnabled; don't signal by sound alone; separate volume for SFX, music, speech ([Accessibility](https://create.roblox.com/docs/en-us/production/publishing/accessibility.md)).
- Community guide (not official): breakpoints at about 600 px (mobile) and 1200 px (tablet), `GetGuiInset()` plus 10 px padding ([playbooks.com](https://playbooks.com/skills/taozhuo/game-dev-skills/ui-ux)).

## Grow A Golem today

- Placeholder UI built in code: dark slate panels (RGB 30,34,40), blue buttons, GothamBold with `TextScaled`.
- Layout: stats panel top-left (level, XP bar, mineral counts); golem health bar top-center with next-goal tracker and progress bar under it; menu buttons on the left; spell buttons Q/E/R bottom-right on touch; toasts bottom-center; event banner. This matches the common simulator layout (target wireframe: `images/hud-layout.png`).
- Moments: boss HP bar, artifact reveal card, level-up banner, damage numbers.
- **Not found in code:** number abbreviation helper, `ScreenInsets`/`CoreUISafeInsets`, ReducedMotion handling, PreferredTextSize support (TextScaled overrides it), PreferredTransparency, gamepad navigation, notification badges.

## Gaps worth closing

1. **P0 (#9):** Set `CoreUISafeInsets` on all interactive ScreenGuis; verify on a notched phone that spell buttons do not overlap the jump button (`images/mobile-safe-areas.png`).
2. **P0:** Add a shared number formatter (K/M/B/T) and use it for minerals, damage numbers and prices.
3. **P1:** Replace `TextScaled` on body text with fixed sizes plus `UITextSizeConstraint`, honoring PreferredTextSize; keep TextScaled only for single big numbers if needed.
4. **P1:** Gate tweens, camera shake and banner slides on `ReducedMotionEnabled`.
5. **P1:** Red "!" badges on Quests/Gifts/Artifacts buttons when something is claimable, with a symbol, not just color.
6. **P1:** Collapse the left menu column into one button on small phones.
7. **P2 (#16):** Cartoony restyle: rounded corners, outlined heavy font, brighter palette, once the loop is playtested.
8. **P2:** Gamepad focus order and input-aware prompts.

## Sources

All accessed 2026-10.
- Roblox Creator Docs, ScreenInsets: https://create.roblox.com/docs/reference/engine/enums/ScreenInsets.md
- Roblox Creator Docs, Position and size: https://create.roblox.com/docs/en-us/ui/position-and-size.md
- Roblox Creator Docs, Cross-platform design: https://create.roblox.com/docs/ui/cross-platform-design
- Roblox Creator Docs, Adaptive design: https://create.roblox.com/docs/production/publishing/adaptive-design.md
- Roblox Creator Docs, Accessibility: https://create.roblox.com/docs/en-us/production/publishing/accessibility.md
- Pet Simulator Wiki, Ranks (PS99): https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99)
- Wikipedia, Grow a Garden: https://en.wikipedia.org/wiki/Grow_a_Garden
- playbooks.com, game-dev-skills ui-ux (community): https://playbooks.com/skills/taozhuo/game-dev-skills/ui-ux
