# Original illustrated UI icons — #179

All artwork comes exclusively from the owner's uploaded `ChatGPT Image Oct 28,
2026, 10_14_32 PM.png` (commit `9734bee`). Its bytes are preserved unchanged.
`source.json` records its SHA-256 and 48 manually aligned crop rectangles;
`crops/` preserves those original pixels. No icons are regenerated or redrawn.

`manifest.json` maps all 37 existing runtime IDs to these crops. `png/` contains
128 × 128 exports with aspect ratio preserved and an 8 px transparent gutter.
`mystical.png` and `mystical-mono.png` retain the existing 1024 × 640 layout,
128 px cells, offsets, and three empty cells. The mono sheet is a grayscale
derivative for the existing tint API. `preview.png` shows runtime icons at
128 px and 32 px, plus grayscale at 32 px.

## Meaning and aliases

The source does not contain every literal game concept. Existing labels remain
necessary: copper uses clay, iron uses the gray golem, stormglass uses ice,
abyssite uses obsidian, sunsteel uses gold, aether uses essence, quake uses
lightning, mend uses potion, magnet and trade use the merging stones, party uses
the moss golem, wardrobe uses the backpack, and alert uses the attention/tap hand.
Rarity IDs use distinct gray, moss, ice, crystal, gold and lava golem silhouettes.
These are visual aliases only; they do not add golem types, change rarity tiers,
or alter odds. The manifest and preview show every mapping explicitly.
All 48 source crops remain available, including the unused gardening/transport
controls, without adding game features. Robux continues to use the existing
`R$` fallback until official Roblox artwork is supplied.

## Upload and use

The HUD, menus and status displays already use `Icons.create` and the stable
registry in `Config.UiIcons`. The illustrated sheets were uploaded on
2026-10-29 as color `132163688139815` and mono `111754038303125`. The older IDs
`130214142096922` / `96019795815429` hold the previous drawn artwork. A GitHub
merge cannot replace hosted image pixels, so any rebuild needs a fresh upload.

1. Upload **both** `mystical.png` and `mystical-mono.png` under the experience
   owner. Keep their dimensions and transparent padding unchanged.
2. After moderation, replace `Config.UiIcons.color` and `.mono` with the new
   usable image IDs. Existing cells and UI consumers need no other changes.
3. In Studio/published play, check HUD minerals/spells, all 13 tabs, rarity
   badges, close, lock and quest states at phone and desktop sizes. Confirm
   readable labels, no clipping/neighbor bleed, and no image-permission errors
   in Output. Test tinted icons as well as full color.

The upload is done; Studio/published validation (step 3) is still an owner step.

## Rebuild and verify

Requires Node and `sharp` 0.35.5. Install with
`npm install --no-save --package-lock=false sharp@0.35.5` if unavailable.

```sh
node assets/ui-icons/build.cjs
node assets/ui-icons/verify.cjs
python3 scripts/check_ui_icons.py
```

The builder crops the original, trims transparent margins, resizes and packs.
It uses SVG only to render preview captions, never to create icon artwork.
Verification checks original bytes, all 48 pixel-exact crops, all 37 aliases,
both packed atlases, registry coordinates, inventory coverage and alpha gutters.
Edit crop rectangles or aliases in the JSON files, then rebuild; do not edit
exported icons or replace the original source. Old SVG icon sources are removed.
