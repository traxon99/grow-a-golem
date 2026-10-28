# Mystical UI icons — issue #83

37 original, code-drawn symbols: thick outlines, simple silhouettes and at most
three colors per icon. `preview.png` shows each at 128 px and 32 px in color and
grayscale. Transparent PNGs and editable SVGs are included. No borrowed artwork.

## Inventory and issue mapping

| Group | Icons | Consumers |
| --- | --- | --- |
| Menu tabs | forge, travel, artifacts, skills, awaken, quests, events, party, hub, trade, wardrobe, shop, ranks | #84, #86–#95 |
| All current Config minerals | stone, copper, iron, crystal, stormglass, abyssite, sunsteel, aether | HUD, #86 |
| Progress | xp, eventPoints | #85, #92, #93, #97 |
| Spells | quake, mend, magnet | HUD, #96 |
| Rarity symbols | common (circle), uncommon (diamond), rare (triangle), epic (four-point star), legendary (five-point star), mythic (six-point star) | shared rarity table in #82, #88, #97 |
| Status | tick, lock, alert, close | #84, #85, #87, #91, #94 |
| Portrait | guide | locked-island dialog #87 |

`manifest.json` records stable IDs, cell coordinates, fallback text and issue
numbers. Rarity symbols are prepared for #82: no artifact rarities or drop odds
are invented or assigned here. Keep the rarity name beside the symbol.

**Robux is intentionally not drawn.** Supply Roblox's official artwork according
to its current brand usage rules, then set `Config.UiIcons.robux`. Until then the
renderer uses `R$` and purchase controls must retain the numeric price.

## Upload and use

1. Upload `mystical.png` and optionally `mystical-mono.png` as images under the
   experience owner. Both are 1024 × 640 RGBA, 8 columns × 5 rows, 128 px per cell.
   Do not crop, rescale or repack them; the final three cells are empty padding.
2. After moderation, paste the numeric image IDs into `Config.UiIcons.color`
   and `.mono`. All asset IDs remain **0** in source until real uploads exist.
3. `src/client/Icons.luau` exports `Icons.create(parent, key, size, position, tint)`.
   No tint selects the color sheet; tint selects the grayscale sheet. It applies
   `ImageRectOffset` / `ImageRectSize` and returns the image, or a text fallback
   when the chosen sheet's ID is zero. An unknown key displays `?`.
4. Test the uploaded sheets in a published place, including permissions, 32 px
   readability, grayscale, small landscape phone and largest preferred text.
   Keep visible word labels and 48 px touch targets; an icon is not a button.

The art and reusable renderer are ready for the menu kit and per-menu work.
Existing screens keep their current text UI until #82/#84–#97 wire in the icons.
This change does not claim that Studio validation or Roblox uploads are done.
If an uploaded image is rejected, reset its ID to zero to restore the fallback.

## Rebuild and edit

Requires Node and `sharp` 0.35.x (tested with the workspace version). Install
locally with `npm install --no-save --package-lock=false sharp@0.35.5` if needed.

```sh
node assets/ui-icons/build.cjs
node assets/ui-icons/verify.cjs
```

`build.cjs` is the geometry source; it exports the individual SVGs under `src/`,
PNGs under `png/`, two SVG/PNG atlases, preview and manifest. Edit the geometry
there to regenerate all outputs. SVGs can also be edited in a vector editor, but
back-port edits into the generator before rebuilding. Preserve order and cell
coordinates, or update `Config.UiIcons.entries` alongside the manifest.

The neutral sheet is white/grayscale for `ImageColor3`; color versions use rune
blue, amethyst, moss and ember, with gold reserved for Legendary and Sunsteel.
No animated glow is baked in. UI glows and reduced-motion behavior belong to #82.
