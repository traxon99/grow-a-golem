--!strict
-- Dresses a zone's flat ground part as a floating low-poly island: a rocky
-- underside, a grass rim, and themed scenery (trees, rocks, lava, crystals).
-- Everything is decoration only (no collisions), and each island is built
-- from a fixed seed so it looks the same every time the server starts.

local Build = require(script.Parent.Build)

local Islands = {}

type Theme = {
	ground: Color3,
	patch: Color3,
	dirt: Color3,
	rock: Color3,
	decor: { [string]: number }, -- decoration kind -> how many
}

local THEMES: { [string]: Theme } = {
	meadow = {
		ground = Color3.fromRGB(104, 158, 76),
		patch = Color3.fromRGB(126, 178, 86),
		dirt = Color3.fromRGB(116, 86, 60),
		rock = Color3.fromRGB(120, 116, 110),
		decor = { roundTree = 22, pineTree = 18, rock = 26, bush = 30, flowers = 30, stump = 6 },
	},
	ember = {
		ground = Color3.fromRGB(92, 64, 54),
		patch = Color3.fromRGB(70, 50, 44),
		dirt = Color3.fromRGB(64, 44, 38),
		rock = Color3.fromRGB(52, 46, 46),
		decor = { basalt = 22, lavaPool = 9, deadTree = 16, rock = 22, crack = 26, ashPile = 12 },
	},
	crystal = {
		ground = Color3.fromRGB(150, 182, 196),
		patch = Color3.fromRGB(178, 204, 216),
		dirt = Color3.fromRGB(96, 104, 128),
		rock = Color3.fromRGB(112, 120, 146),
		decor = { crystalCluster = 26, glassTree = 20, rock = 18, shardSpike = 20, frostBush = 24 },
	},
}

-- Ground patches in a slightly different shade break up the flat top.
local function addPatches(parent: Instance, rng: Random, theme: Theme, top: CFrame, size: Vector3)
	for _ = 1, 40 do
		local w = rng:NextNumber(14, 34)
		local d = rng:NextNumber(14, 34)
		local x = rng:NextNumber(-size.X / 2 + w / 2, size.X / 2 - w / 2)
		local z = rng:NextNumber(-size.Z / 2 + d / 2, size.Z / 2 - d / 2)
		Build.part(parent, {
			size = Vector3.new(w, 0.2, d),
			cframe = top * CFrame.new(x, 0.05, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			color = Build.vary(theme.patch, rng, 0.05),
		})
	end
end

-- The underside: stacked layers that shrink toward a point, each one a
-- square plus a 45-degree square, which reads as a chunky rock cone.
local function addUnderside(parent: Instance, rng: Random, theme: Theme, ground: BasePart)
	local size = ground.Size
	local bottom = ground.CFrame * CFrame.new(0, -size.Y / 2, 0)
	local y = 0
	local layers = 6
	for i = 1, layers do
		local t = (i - 1) / layers
		local w = size.X * (1 - t * 0.85)
		local d = size.Z * (1 - t * 0.85)
		local h = 10 + i * 2
		local color = if i <= 2 then theme.dirt else Build.vary(theme.rock, rng, 0.04)
		local layerCf = bottom * CFrame.new(rng:NextNumber(-4, 4), y - h / 2, rng:NextNumber(-4, 4))
		Build.part(parent, { size = Vector3.new(w, h, d), cframe = layerCf, color = color, name = "Underside" })
		Build.part(parent, {
			size = Vector3.new(w * 0.74, h * 0.9, d * 0.74),
			cframe = layerCf * CFrame.new(0, -h * 0.1, 0) * CFrame.Angles(0, math.rad(45), 0),
			color = Build.vary(color, rng, 0.04),
			name = "Underside",
		})
		y -= h * 0.85
	end
	-- A few loose rocks hanging under the edges.
	for _ = 1, 14 do
		local s = rng:NextNumber(6, 16)
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.3, 0.42)
		Build.part(parent, {
			size = Vector3.new(s, s * 1.4, s),
			cframe = bottom
				* CFrame.new(math.cos(angle) * size.X * r, -rng:NextNumber(4, 20), math.sin(angle) * size.Z * r)
				* Build.tumble(rng, 30),
			color = Build.vary(theme.rock, rng),
			name = "HangingRock",
		})
	end
	-- Dirt band under the grass so the edge has a visible "cliff" lip.
	Build.part(parent, {
		size = Vector3.new(size.X - 1, 3, size.Z - 1),
		cframe = bottom * CFrame.new(0, -1.5, 0),
		color = theme.dirt,
		name = "Lip",
	})
end

---------------------------------------------------------------- decorations

local DECOR: { [string]: (Instance, Random, CFrame, Theme) -> () } = {}

function DECOR.rock(parent, rng, at, theme)
	local s = rng:NextNumber(3, 9)
	for _ = 1, 2 do
		Build.part(parent, {
			size = Vector3.new(s * rng:NextNumber(0.8, 1.3), s * rng:NextNumber(0.6, 1), s * rng:NextNumber(0.8, 1.3)),
			cframe = at * CFrame.new(rng:NextNumber(-1, 1), s * 0.2, rng:NextNumber(-1, 1)) * Build.tumble(rng, 35),
			color = Build.vary(theme.rock, rng),
		})
	end
end

function DECOR.roundTree(parent, rng, at, _theme)
	local height = rng:NextNumber(9, 15)
	Build.part(parent, {
		size = Vector3.new(1.6, height, 1.6),
		cframe = at * CFrame.new(0, height / 2, 0),
		color = Color3.fromRGB(110, 78, 52),
	})
	local leaf = Color3.fromRGB(70, 140, 60)
	for i = 1, 3 do
		local s = rng:NextNumber(6, 9) - i * 0.6
		Build.part(parent, {
			size = Vector3.new(s, s, s),
			cframe = at
				* CFrame.new(rng:NextNumber(-1.5, 1.5), height + (i - 1) * 1.8, rng:NextNumber(-1.5, 1.5))
				* CFrame.Angles(math.rad(45), rng:NextNumber(0, math.pi), math.rad(35)),
			color = Build.vary(leaf, rng, 0.1),
		})
	end
end

function DECOR.pineTree(parent, rng, at, _theme)
	local height = rng:NextNumber(4, 6)
	Build.part(parent, {
		size = Vector3.new(1.4, height, 1.4),
		cframe = at * CFrame.new(0, height / 2, 0),
		color = Color3.fromRGB(96, 68, 46),
	})
	local leaf = Color3.fromRGB(48, 110, 70)
	local y = height
	for i = 1, 4 do
		local w = 9 - i * 1.8
		local h = 3.2
		Build.part(parent, {
			size = Vector3.new(w, h, w),
			cframe = at * CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, math.rad(i * 45), 0),
			color = Build.vary(leaf, rng, 0.06),
		})
		y += h * 0.8
	end
end

function DECOR.bush(parent, rng, at, _theme)
	local s = rng:NextNumber(2.5, 4.5)
	Build.part(parent, {
		size = Vector3.new(s, s, s),
		cframe = at * CFrame.new(0, s * 0.3, 0) * CFrame.Angles(math.rad(45), rng:NextNumber(0, math.pi), math.rad(45)),
		color = Build.vary(Color3.fromRGB(80, 150, 66), rng, 0.1),
	})
end

local FLOWER_COLORS = {
	Color3.fromRGB(255, 220, 90),
	Color3.fromRGB(255, 130, 160),
	Color3.fromRGB(240, 240, 255),
	Color3.fromRGB(170, 140, 255),
}

function DECOR.flowers(parent, rng, at, _theme)
	local color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
	for _ = 1, rng:NextInteger(3, 6) do
		local offset = CFrame.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		Build.part(parent, {
			size = Vector3.new(0.2, 1, 0.2),
			cframe = at * offset * CFrame.new(0, 0.5, 0),
			color = Color3.fromRGB(70, 130, 60),
		})
		Build.part(parent, {
			size = Vector3.new(0.6, 0.6, 0.6),
			cframe = at * offset * CFrame.new(0, 1.1, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			color = color,
		})
	end
end

function DECOR.stump(parent, rng, at, _theme)
	Build.cylinder(parent, 1.6, rng:NextNumber(2.2, 3), at * CFrame.new(0, 0.8, 0), Color3.fromRGB(120, 88, 60))
	Build.cylinder(parent, 0.1, 1.8, at * CFrame.new(0, 1.62, 0), Color3.fromRGB(196, 160, 112))
end

function DECOR.basalt(parent, rng, at, theme)
	for _ = 1, rng:NextInteger(3, 6) do
		local h = rng:NextNumber(4, 16)
		local d = rng:NextNumber(2.2, 3.6)
		Build.cylinder(
			parent,
			h,
			d,
			at * CFrame.new(rng:NextNumber(-3, 3), h / 2 - 0.5, rng:NextNumber(-3, 3)) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08)),
			Build.vary(theme.rock, rng, 0.05),
			Enum.Material.Basalt
		)
	end
end

function DECOR.lavaPool(parent, rng, at, theme)
	local d = rng:NextNumber(10, 20)
	Build.cylinder(parent, 0.6, d + 3, at * CFrame.new(0, 0.2, 0), theme.rock)
	local lava = Build.cylinder(parent, 0.6, d, at * CFrame.new(0, 0.35, 0), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = d
	light.Brightness = 1.5
	light.Parent = lava
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 180, 80), Color3.fromRGB(255, 70, 30))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.3, 0)
	embers.Lifetime = NumberRange.new(1.5, 3)
	embers.Rate = 6
	embers.Speed = NumberRange.new(2, 5)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis points up
	embers.Parent = lava
end

function DECOR.deadTree(parent, rng, at, _theme)
	local h = rng:NextNumber(8, 13)
	local bark = Color3.fromRGB(46, 36, 34)
	local trunk = at * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.1, 0.1))
	Build.part(parent, { size = Vector3.new(1.4, h, 1.4), cframe = trunk * CFrame.new(0, h / 2, 0), color = bark })
	for i = 1, 3 do
		local len = rng:NextNumber(3, 5)
		local y = h * (0.5 + i * 0.13)
		local yaw = rng:NextNumber(0, math.pi * 2)
		Build.part(parent, {
			size = Vector3.new(0.7, len, 0.7),
			cframe = trunk * CFrame.new(0, y, 0) * CFrame.Angles(0, yaw, math.rad(50)) * CFrame.new(0, len / 2, 0),
			color = bark,
		})
	end
end

function DECOR.crack(parent, rng, at, _theme)
	Build.part(parent, {
		size = Vector3.new(rng:NextNumber(6, 14), 0.15, rng:NextNumber(0.4, 0.9)),
		cframe = at * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		color = Color3.fromRGB(255, 110, 40),
		material = Enum.Material.Neon,
	})
end

function DECOR.ashPile(parent, rng, at, _theme)
	local s = rng:NextNumber(3, 6)
	Build.part(parent, {
		size = Vector3.new(s, s * 0.5, s),
		cframe = at * CFrame.new(0, 0, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(45)),
		color = Build.vary(Color3.fromRGB(110, 104, 100), rng),
	})
end

local CRYSTAL_COLORS = {
	Color3.fromRGB(150, 120, 255),
	Color3.fromRGB(120, 200, 255),
	Color3.fromRGB(220, 160, 255),
}

function DECOR.crystalCluster(parent, rng, at, _theme)
	local color = CRYSTAL_COLORS[rng:NextInteger(1, #CRYSTAL_COLORS)]
	for i = 1, rng:NextInteger(3, 6) do
		local h = rng:NextNumber(3, 9) * (if i == 1 then 1.4 else 1)
		local w = h * 0.22
		local tilt = if i == 1 then CFrame.identity else CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5))
		local crystal = Build.part(parent, {
			size = Vector3.new(w, h, w),
			cframe = at * tilt * CFrame.new(0, h / 2 - 0.5, 0) * CFrame.Angles(0, math.rad(45), 0),
			color = Build.vary(color, rng, 0.06),
			material = Enum.Material.Glass,
			transparency = 0.15,
		})
		if i == 1 then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 14
			light.Brightness = 1.2
			light.Parent = crystal
		end
	end
end

function DECOR.glassTree(parent, rng, at, _theme)
	local h = rng:NextNumber(8, 12)
	Build.part(parent, {
		size = Vector3.new(1.3, h, 1.3),
		cframe = at * CFrame.new(0, h / 2, 0),
		color = Color3.fromRGB(230, 236, 245),
	})
	for i = 1, 3 do
		local s = rng:NextNumber(4, 7)
		Build.part(parent, {
			size = Vector3.new(s, s * 1.3, s),
			cframe = at
				* CFrame.new(rng:NextNumber(-1.5, 1.5), h + i * 1.2, rng:NextNumber(-1.5, 1.5))
				* CFrame.Angles(math.rad(45), rng:NextNumber(0, math.pi), math.rad(45)),
			color = Build.vary(Color3.fromRGB(150, 220, 235), rng, 0.08),
			material = Enum.Material.Glass,
			transparency = 0.25,
		})
	end
end

function DECOR.shardSpike(parent, rng, at, theme)
	local h = rng:NextNumber(5, 12)
	Build.part(parent, {
		size = Vector3.new(h * 0.25, h, h * 0.25),
		cframe = at * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)) * CFrame.new(0, h / 2 - 1, 0) * CFrame.Angles(0, math.rad(45), 0),
		color = Build.vary(theme.rock, rng),
	})
end

function DECOR.frostBush(parent, rng, at, _theme)
	local s = rng:NextNumber(2, 3.5)
	Build.part(parent, {
		size = Vector3.new(s, s, s),
		cframe = at * CFrame.new(0, s * 0.3, 0) * CFrame.Angles(math.rad(45), rng:NextNumber(0, math.pi), math.rad(45)),
		color = Build.vary(Color3.fromRGB(200, 230, 240), rng, 0.06),
	})
end

---------------------------------------------------------------- floating extras

local function addCloud(parent: Instance, rng: Random, at: Vector3)
	local white = Color3.fromRGB(245, 248, 255)
	for _ = 1, rng:NextInteger(4, 7) do
		local s = rng:NextNumber(10, 22)
		Build.part(parent, {
			size = Vector3.new(s, s * 0.6, s),
			cframe = CFrame.new(at + Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(-3, 3), rng:NextNumber(-10, 10))),
			color = white,
			shape = Enum.PartType.Ball,
			transparency = 0.1,
			name = "Cloud",
		})
	end
end

local function addIslet(parent: Instance, rng: Random, theme: Theme, at: Vector3)
	local s = rng:NextNumber(10, 20)
	local top = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	Build.part(parent, { size = Vector3.new(s, 2, s), cframe = top, color = theme.ground, name = "Islet" })
	Build.part(parent, {
		size = Vector3.new(s * 0.8, s * 0.7, s * 0.8),
		cframe = top * CFrame.new(0, -s * 0.35, 0) * CFrame.Angles(0, math.rad(45), 0),
		color = theme.rock,
		name = "Islet",
	})
	Build.part(parent, {
		size = Vector3.new(s * 0.4, s * 0.6, s * 0.4),
		cframe = top * CFrame.new(0, -s * 0.8, 0) * CFrame.Angles(math.rad(10), 0, math.rad(10)),
		color = Build.vary(theme.rock, rng),
		name = "Islet",
	})
end

---------------------------------------------------------------- public

export type Options = {
	theme: string,
	seed: number,
	keepClear: { { position: Vector3, radius: number } }, -- spawn, boss home...
}

-- Builds scenery for `ground` (the zone's walkable part) into a new model.
function Islands.decorate(ground: BasePart, options: Options): Model
	local theme = THEMES[options.theme] or THEMES.meadow
	local rng = Random.new(options.seed)
	local model = Instance.new("Model")
	model.Name = ground.Name .. "Scenery"

	ground.Color = theme.ground
	ground.Material = Enum.Material.SmoothPlastic

	local size = ground.Size
	local top = ground.CFrame * CFrame.new(0, size.Y / 2, 0)
	addPatches(model, rng, theme, top, size)
	addUnderside(model, rng, theme, ground)

	local margin = 8
	local function clear(point: Vector3): boolean
		for _, zone in options.keepClear do
			local flat = (point - zone.position) * Vector3.new(1, 0, 1)
			if flat.Magnitude < zone.radius then
				return false
			end
		end
		return true
	end

	for kind, count in theme.decor do
		local builder = DECOR[kind]
		for _ = 1, count do
			for _ = 1, 8 do
				local x = rng:NextNumber(-size.X / 2 + margin, size.X / 2 - margin)
				local z = rng:NextNumber(-size.Z / 2 + margin, size.Z / 2 - margin)
				local at = top * CFrame.new(x, 0, z)
				if clear(at.Position) then
					local placement = at * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
					local anchor = Build.part(model, {
						name = "PropAnchor", size = Vector3.new(0.1, 0.1, 0.1), cframe = placement,
						color = theme.rock, transparency = 1,
					})
					if not Build.attachAsset(model, anchor, { "Props", kind }, rng:NextNumber(0.8, 1.2)) then
						anchor:Destroy()
						builder(model, rng, placement, theme)
					end
					break
				end
			end
		end
	end

	-- Edge rocks so the rim reads as a cliff, not a cut-off slab.
	for i = 1, 48 do
		local side = i % 4
		local along = rng:NextNumber(-0.5, 0.5)
		local x = if side == 0 then -0.5 elseif side == 1 then 0.5 else along
		local z = if side == 2 then -0.5 elseif side == 3 then 0.5 else along
		local s = rng:NextNumber(3, 7)
		Build.part(model, {
			size = Vector3.new(s, s, s),
			cframe = top * CFrame.new(x * size.X, -s * 0.3, z * size.Z) * Build.tumble(rng, 40),
			color = Build.vary(theme.rock, rng),
			name = "EdgeRock",
		})
	end

	-- Clouds and little floating rocks around the island.
	local center = top.Position
	for _ = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = size.X * rng:NextNumber(0.6, 0.9)
		addCloud(model, rng, center + Vector3.new(math.cos(angle) * r, rng:NextNumber(-60, -10), math.sin(angle) * r))
	end
	for _ = 1, 5 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = size.X * rng:NextNumber(0.62, 0.75)
		addIslet(model, rng, theme, center + Vector3.new(math.cos(angle) * r, rng:NextNumber(-25, 10), math.sin(angle) * r))
	end

	model.Parent = workspace
	return model
end

return Islands
