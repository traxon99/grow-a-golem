-- CosmeticLooks's pure color/material logic. The check script bundles the
-- real Config and CosmeticLooks above this file (every other service stubs
-- CosmeticLooks out entirely, so this is its only real exercise).
--
-- Out of scope: buildPet/dress and their private helpers (makePart,
-- outfitPieces, the pet builders) construct real Part/Model/CFrame
-- instances, well beyond what this harness shims, for mostly instance
-- assembly rather than logic. partLook's `shade` parameter (an HSV
-- darken/lighten via Color3:ToHSV/Color3.fromHSV) is out of scope too: the
-- shared Color3 shim only has fromRGB and Lerp.
do
	-- No tier, no skin: the bare color and its default material.
	local bareColor, bareMaterial = CosmeticLooks.partLook(nil, nil, nil)
	assert(
		bareColor.R == CosmeticLooks.BARE_COLOR.R
			and bareColor.G == CosmeticLooks.BARE_COLOR.G
			and bareColor.B == CosmeticLooks.BARE_COLOR.B,
		"no tier falls back to BARE_COLOR"
	)
	assert(bareMaterial == Enum.Material.Slate, "no tier falls back to Slate")

	-- A real tier, no skin: the tier's own color and material pass through.
	local tier = Config.Tiers.copper
	local tierColor, tierMaterial = CosmeticLooks.partLook("copper", nil, nil)
	assert(
		tierColor.R == tier.color.R and tierColor.G == tier.color.G and tierColor.B == tier.color.B,
		"a tier with no skin keeps its own color"
	)
	assert(tierMaterial == tier.material, "a tier with no skin keeps its own material")

	-- A real tier with a skin equipped: the tier color lerped toward the
	-- skin's color by the skin's tint, and the skin's material.
	local skin = Config.Cosmetics.mossy.skin
	local skinnedColor, skinnedMaterial = CosmeticLooks.partLook("copper", nil, "mossy")
	local expectedR = tier.color.R + (skin.color.R - tier.color.R) * skin.tint
	local expectedG = tier.color.G + (skin.color.G - tier.color.G) * skin.tint
	local expectedB = tier.color.B + (skin.color.B - tier.color.B) * skin.tint
	assert(
		math.abs(skinnedColor.R - expectedR) < 1e-9
			and math.abs(skinnedColor.G - expectedG) < 1e-9
			and math.abs(skinnedColor.B - expectedB) < 1e-9,
		"a skin lerps the tier color toward its own by its tint"
	)
	assert(skinnedMaterial == skin.material, "a skin swaps in its own material")

	-- An unrecognized tier id behaves like no tier at all.
	local unknownColor, unknownMaterial = CosmeticLooks.partLook("not-a-tier", nil, nil)
	assert(
		unknownColor.R == CosmeticLooks.BARE_COLOR.R and unknownMaterial == Enum.Material.Slate,
		"an unrecognized tier id falls back to bare"
	)

	-- accent: the default rune color with no skin, the skin's own accent
	-- color with one equipped.
	local defaultAccent = CosmeticLooks.accent(nil)
	assert(
		defaultAccent.R == CosmeticLooks.RUNE_COLOR.R
			and defaultAccent.G == CosmeticLooks.RUNE_COLOR.G
			and defaultAccent.B == CosmeticLooks.RUNE_COLOR.B,
		"no skin falls back to RUNE_COLOR"
	)
	local lavaAccent = Config.Cosmetics.lava.skin.accent
	local skinnedAccent = CosmeticLooks.accent("lava")
	assert(
		skinnedAccent.R == lavaAccent.R and skinnedAccent.G == lavaAccent.G and skinnedAccent.B == lavaAccent.B,
		"a skin's own accent color replaces RUNE_COLOR"
	)

	print("cosmetic-looks: ok")
end
