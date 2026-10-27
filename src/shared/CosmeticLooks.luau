--!strict
-- How cosmetics look. Shared so the server builds the real thing and the
-- client's Wardrobe preview builds exactly the same thing. Names, prices and
-- unlocks live in Config.Cosmetics; this file only has shapes and colors.
-- Nothing here touches stats.

local Config = require(script.Parent:WaitForChild("Config"))

local CosmeticLooks = {}

CosmeticLooks.BARE_COLOR = Color3.fromRGB(110, 104, 96) -- a slot with no forged part
CosmeticLooks.RUNE_COLOR = Color3.fromRGB(90, 200, 255)

---------------------------------------------------------------- skins

local function skinOf(skinId: string?): any
	local cosmetic = skinId and Config.Cosmetics[skinId]
	return cosmetic and cosmetic.skin
end

-- Color and material of one golem body part: its forged tier, tinted by the
-- skin. `shade` darkens or lightens it (trim pieces use 0.8 to 0.85).
function CosmeticLooks.partLook(tierId: string?, shade: number?, skinId: string?): (Color3, Enum.Material)
	local tier = tierId and Config.Tiers[tierId]
	local color = if tier then tier.color else CosmeticLooks.BARE_COLOR
	local material = if tier then tier.material else Enum.Material.Slate
	local skin = skinOf(skinId)
	if skin then
		color = color:Lerp(skin.color, skin.tint)
		material = skin.material
	end
	if shade then
		local h, s, v = color:ToHSV()
		color = Color3.fromHSV(h, s, math.clamp(v * shade, 0, 1))
	end
	return color, material
end

-- The glowing runes and eyes.
function CosmeticLooks.accent(skinId: string?): Color3
	local skin = skinOf(skinId)
	return if skin then skin.accent else CosmeticLooks.RUNE_COLOR
end

---------------------------------------------------------------- parts

type Piece = {
	name: string,
	size: Vector3,
	at: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: string?, -- "ball", "cylinder" (standing up), or nil for a block
	transparency: number?,
	anchor: string?, -- outfits only: "head", "torso" or "hand"
}

local function V(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
end

-- An anchored, non-colliding part for `piece`, placed relative to `origin`.
local function makePart(parent: Instance, piece: Piece, origin: CFrame, scale: number): Part
	local part = Instance.new("Part")
	part.Name = piece.name
	local size = piece.size * scale
	local cframe = origin * (CFrame.new(piece.at.Position * scale) * piece.at.Rotation)
	if piece.shape == "ball" then
		part.Shape = Enum.PartType.Ball
	elseif piece.shape == "cylinder" then
		-- Roblox cylinders lie along X; stand this one up.
		part.Shape = Enum.PartType.Cylinder
		size = Vector3.new(size.Y, size.X, size.X)
		cframe *= CFrame.Angles(0, 0, math.rad(90))
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = piece.color
	part.Material = piece.material or Enum.Material.SmoothPlastic
	part.Transparency = piece.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

---------------------------------------------------------------- pets

-- Drawn at scale 1, centered on the pet, facing -Z like the golem.
-- The first piece is the body the others hang on.
local function pebblePup(): { Piece }
	local stone, dark = Color3.fromRGB(128, 122, 110), Color3.fromRGB(98, 93, 85)
	local pieces: { Piece } = {
		{ name = "Body", size = V(2, 1.6, 2.6), at = at(0, 0, 0), color = stone, material = Enum.Material.Slate },
		{ name = "Head", size = V(1.7, 1.5, 1.5), at = at(0, 0.9, -1.5), color = stone, material = Enum.Material.Slate },
		{ name = "Snout", size = V(0.9, 0.6, 0.5), at = at(0, 0.6, -2.4), color = dark, material = Enum.Material.Slate },
		{ name = "Nose", size = V(0.3, 0.25, 0.15), at = at(0, 0.85, -2.68), color = Color3.fromRGB(30, 30, 30) },
		{ name = "Tail", size = V(0.4, 0.4, 1.1), at = at(0, 0.7, 1.6, 0.6), color = dark, material = Enum.Material.Slate },
	}
	for _, side in { -1, 1 } do
		table.insert(pieces, { name = "Ear", size = V(0.4, 0.7, 0.3), at = at(side * 0.55, 1.85, -1.4, 0, 0, side * -0.3), color = dark, material = Enum.Material.Slate })
		table.insert(pieces, { name = "Eye", size = V(0.25, 0.25, 0.1), at = at(side * 0.4, 1.15, -2.27), color = CosmeticLooks.RUNE_COLOR, material = Enum.Material.Neon })
		for _, z in { -0.85, 0.85 } do
			table.insert(pieces, { name = "Leg", size = V(0.55, 0.7, 0.55), at = at(side * 0.6, -1.05, z), color = dark, material = Enum.Material.Slate })
		end
	end
	return pieces
end

local function emberSprite(): { Piece }
	local flame = Color3.fromRGB(255, 140, 40)
	local pieces: { Piece } = {
		{ name = "Body", size = V(1.6, 1.6, 1.6), at = at(0, 0, 0), color = flame, material = Enum.Material.Neon, shape = "ball" },
		{ name = "Glow", size = V(2.2, 2.2, 2.2), at = at(0, 0, 0), color = Color3.fromRGB(255, 90, 20), material = Enum.Material.Neon, shape = "ball", transparency = 0.7 },
		{ name = "Flame", size = V(0.8, 0.9, 0.8), at = at(0, 1, 0.1, 0, 0.8, 0), color = flame, material = Enum.Material.Neon },
		{ name = "FlameTip", size = V(0.45, 0.6, 0.45), at = at(0, 1.6, 0.2, 0, 0.3, 0), color = Color3.fromRGB(255, 220, 110), material = Enum.Material.Neon },
	}
	for _, side in { -1, 1 } do
		table.insert(pieces, { name = "Wing", size = V(1.4, 0.1, 0.8), at = at(side * 1.2, 0.2, 0.3, 0, 0, side * 0.4), color = Color3.fromRGB(255, 200, 90), material = Enum.Material.Neon, transparency = 0.2 })
		table.insert(pieces, { name = "Eye", size = V(0.22, 0.3, 0.1), at = at(side * 0.3, 0.15, -0.8), color = Color3.fromRGB(60, 20, 10) })
	end
	return pieces
end

local function crystalOwl(): { Piece }
	local crystal, deep, gold = Color3.fromRGB(150, 110, 255), Color3.fromRGB(120, 85, 220), Color3.fromRGB(255, 190, 70)
	local glass = Enum.Material.Glass
	local pieces: { Piece } = {
		{ name = "Body", size = V(1.8, 2, 1.6), at = at(0, 0, 0), color = crystal, material = glass },
		{ name = "Belly", size = V(1.2, 1.3, 0.2), at = at(0, -0.2, -0.82), color = Color3.fromRGB(200, 180, 255), material = glass },
		{ name = "Head", size = V(1.7, 1.3, 1.5), at = at(0, 1.55, 0), color = crystal, material = glass },
		{ name = "Beak", size = V(0.3, 0.35, 0.3), at = at(0, 1.3, -0.85), color = gold },
	}
	for _, side in { -1, 1 } do
		table.insert(pieces, { name = "Tuft", size = V(0.35, 0.6, 0.35), at = at(side * 0.6, 2.4, 0, 0, 0, side * -0.35), color = deep, material = glass })
		table.insert(pieces, { name = "Eye", size = V(0.5, 0.5, 0.5), at = at(side * 0.4, 1.65, -0.72), color = Color3.fromRGB(255, 240, 140), material = Enum.Material.Neon, shape = "ball" })
		table.insert(pieces, { name = "Wing", size = V(0.3, 1.6, 1.2), at = at(side * 1.05, -0.05, 0.1), color = deep, material = glass })
		table.insert(pieces, { name = "Foot", size = V(0.6, 0.25, 0.5), at = at(side * 0.45, -1.1, -0.2), color = gold })
	end
	return pieces
end

local PETS: { [string]: () -> { Piece } } = {
	pebblePup = pebblePup,
	emberSprite = emberSprite,
	crystalOwl = crystalOwl,
}

-- Builds a pet's parts (anchored) centered on `origin`. Returns the body
-- first and the rest after, or nil for an unknown pet.
function CosmeticLooks.buildPet(id: string, parent: Instance, origin: CFrame, scale: number): (Part?, { Part })
	local design = PETS[id]
	if not design then
		return nil, {}
	end
	local body: Part? = nil
	local rest = {}
	for index, piece in design() do
		local part = makePart(parent, piece, origin, scale)
		if index == 1 then
			body = part
		else
			table.insert(rest, part)
		end
	end
	return body, rest
end

---------------------------------------------------------------- outfits

type Palette = { hat: Color3, band: Color3, cape: Color3, staff: Color3, gem: Color3, stars: boolean? }

local OUTFITS: { [string]: Palette } = {
	apprentice = {
		hat = Color3.fromRGB(60, 90, 200),
		band = Color3.fromRGB(240, 200, 80),
		cape = Color3.fromRGB(50, 70, 170),
		staff = Color3.fromRGB(130, 90, 55),
		gem = Color3.fromRGB(90, 200, 255),
	},
	emberMage = {
		hat = Color3.fromRGB(190, 50, 30),
		band = Color3.fromRGB(60, 30, 25),
		cape = Color3.fromRGB(150, 35, 25),
		staff = Color3.fromRGB(60, 45, 40),
		gem = Color3.fromRGB(255, 120, 30),
	},
	starlight = {
		hat = Color3.fromRGB(30, 34, 90),
		band = Color3.fromRGB(180, 200, 255),
		cape = Color3.fromRGB(25, 28, 75),
		staff = Color3.fromRGB(230, 230, 240),
		gem = Color3.fromRGB(120, 240, 255),
		stars = true,
	},
}

-- Drawn in "head units" (1 = the avatar's head height), relative to the
-- head, upper torso, or right hand.
local function outfitPieces(palette: Palette): { Piece }
	local fabric = Enum.Material.Fabric
	local pieces: { Piece } = {
		{ name = "HatBrim", anchor = "head", size = V(2, 0.12, 2), at = at(0, 0.5, 0), color = palette.hat, material = fabric, shape = "cylinder" },
		{ name = "HatBand", anchor = "head", size = V(1.22, 0.14, 1.22), at = at(0, 0.62, 0), color = palette.band, material = fabric, shape = "cylinder" },
		{ name = "Hat1", anchor = "head", size = V(1.15, 0.45, 1.15), at = at(0, 0.8, 0), color = palette.hat, material = fabric, shape = "cylinder" },
		{ name = "Hat2", anchor = "head", size = V(0.85, 0.4, 0.85), at = at(0, 1.2, 0.05), color = palette.hat, material = fabric, shape = "cylinder" },
		{ name = "Hat3", anchor = "head", size = V(0.55, 0.35, 0.55), at = at(0, 1.54, 0.15), color = palette.hat, material = fabric, shape = "cylinder" },
		{ name = "HatTip", anchor = "head", size = V(0.3, 0.3, 0.3), at = at(0, 1.78, 0.28), color = if palette.stars then palette.gem else palette.hat, material = if palette.stars then Enum.Material.Neon else fabric, shape = "ball" },
		{ name = "Cape", anchor = "torso", size = V(1.7, 2.1, 0.1), at = at(0, -0.35, 0.6), color = palette.cape, material = fabric },
		{ name = "Staff", anchor = "hand", size = V(0.2, 4, 0.2), at = at(0, 1.2, 0), color = palette.staff, material = Enum.Material.Wood, shape = "cylinder" },
		{ name = "Gem", anchor = "hand", size = V(0.5, 0.5, 0.5), at = at(0, 3.3, 0), color = palette.gem, material = Enum.Material.Neon, shape = "ball" },
	}
	if palette.stars then
		for _, spot in { at(-0.4, 0.1, 0.66, 0, 0, 0.6), at(0.35, -0.6, 0.66, 0, 0, 0.2), at(-0.1, -1.1, 0.66, 0, 0, 0.9) } do
			table.insert(pieces, { name = "Star", anchor = "torso", size = V(0.18, 0.18, 0.04), at = spot, color = palette.band, material = Enum.Material.Neon })
		end
	end
	return pieces
end

local OUTFIT_NAME = "WizardOutfit"
local HIDDEN_ATTRIBUTE = "OutfitHiddenTransparency"

-- Dresses a character in an outfit, replacing any outfit already on it.
-- Pass nil to take it off. Hat accessories are hidden under the wizard hat
-- and come back when the outfit comes off.
function CosmeticLooks.dress(character: Model, id: string?)
	local old = character:FindFirstChild(OUTFIT_NAME)
	if old then
		old:Destroy()
	end
	for _, child in character:GetChildren() do
		local handle = child:IsA("Accessory") and child:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			local saved = handle:GetAttribute(HIDDEN_ATTRIBUTE)
			if type(saved) == "number" then
				handle.Transparency = saved
				handle:SetAttribute(HIDDEN_ATTRIBUTE, nil)
			end
		end
	end

	local palette = id and OUTFITS[id]
	local head = character:FindFirstChild("Head")
	if not palette or not (head and head:IsA("BasePart")) then
		return
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local unit = head.Size.Y

	local outfit = Instance.new("Model")
	outfit.Name = OUTFIT_NAME
	for _, piece in outfitPieces(palette) do
		local anchor: Instance? = if piece.anchor == "torso" then torso elseif piece.anchor == "hand" then hand else head
		if anchor and anchor:IsA("BasePart") then
			local origin = anchor.CFrame
			if anchor.Name == "Right Arm" then
				origin *= CFrame.new(0, -anchor.Size.Y / 2, 0) -- R6 arms have no hand part
			end
			local part = makePart(outfit, piece, origin, unit)
			part.Anchored = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchor
			weld.Part1 = part
			weld.Parent = part
		end
	end
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and child.AccessoryType == Enum.AccessoryType.Hat then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle:SetAttribute(HIDDEN_ATTRIBUTE, handle.Transparency)
				handle.Transparency = 1
			end
		end
	end
	outfit.Parent = character
end

return CosmeticLooks
