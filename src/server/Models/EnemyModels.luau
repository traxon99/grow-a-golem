--!strict
-- Low-poly enemy and boss models, built in code around an invisible
-- HumanoidRootPart. Each design is drawn at its Config size, then scaled if
-- that size is changed. Limbs are Motor6D joints so the client animator can
-- make them walk, punch, and slam (see Build.rig for the joint attributes).
-- Every model has a part named "Head" so Roblox shows its name and health.

local Build = require(script.Parent.Build)

local EnemyModels = {}

local V = Vector3.new
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass

local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Brightness = brightness
	pointLight.Parent = parent
end

local function embers(parent: Instance, color: Color3, rate: number, size: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.fromRGB(255, 60, 20))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(size, 0)
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Acceleration = V(0, 3, 0)
	emitter.Parent = parent
end

type Design = {
	height: number, -- design height; the model scales to def.size.Y / height
	stride: number, -- studs per walk cycle at scale 1
	build: (rig: Build.Rig, root: BasePart, def: any) -> (),
}

local DESIGNS: { [string]: Design } = {}

-- A round, mossy pebble on four stubby legs.
DESIGNS.pebbleCritter = {
	height = 3,
	stride = 2.2,
	build = function(rig, root, def)
		local stone = def.color
		local body = rig.part("Head", V(2.8, 2.1, 2.8), at(0, -0.3, 0), stone)
		rig.joint(root, body, V(0, -1, 0), "Body", { Kind = "body" })
		rig.weld(body, rig.part("Facet", V(2.3, 2.5, 2.3), at(0, -0.1, 0, 0, 45, 0), Build.vary(stone, Random.new(1))))
		rig.weld(body, rig.part("Moss", V(1.8, 0.4, 1.6), at(0.1, 1.05, 0.2, 0, 20, 0), Color3.fromRGB(96, 150, 70)))
		rig.weld(body, rig.part("Pebble", V(0.6, 0.6, 0.6), at(-0.4, 1.35, 0.3, 30, 20, 10), stone))
		for _, x in { -0.55, 0.55 } do
			rig.weld(body, rig.part("Eye", V(0.45, 0.45, 0.15), at(x, 0.1, -1.42), Color3.fromRGB(255, 220, 120), NEON))
		end
		for _, leg in { { -0.9, -0.8, 1 }, { 0.9, -0.8, -1 }, { -0.9, 0.8, -1 }, { 0.9, 0.8, 1 } } do
			local part = rig.part("Leg", V(0.7, 0.9, 0.7), at(leg[1], -1.55, leg[2]), Build.vary(stone, Random.new(2), 0.1))
			rig.joint(root, part, V(leg[1], -1.1, leg[2]), "Hip", { Kind = "leg", Side = leg[3] })
		end
	end,
}

-- A small horned fire imp with a glowing belly and a pointed tail.
DESIGNS.cinderImp = {
	height = 4,
	stride = 2.6,
	build = function(rig, root, def)
		local skin = def.color
		local dark = Color3.fromRGB(50, 34, 32)
		local glow = Color3.fromRGB(255, 170, 60)
		for _, side in { -1, 1 } do
			local leg = rig.part("Leg", V(0.7, 1.4, 0.7), at(side * 0.5, -1.8, 0), Build.vary(skin, Random.new(3)))
			rig.joint(root, leg, V(side * 0.5, -1.1, 0), "Hip", { Kind = "leg", Side = side })
		end
		local torso = rig.part("Torso", V(1.8, 1.6, 1.2), at(0, -0.3, 0), skin)
		rig.joint(root, torso, V(0, -1.1, 0), "Body", { Kind = "body" })
		rig.weld(torso, rig.part("Core", V(0.7, 0.7, 0.15), at(0, -0.2, -0.62), glow, NEON))
		local tail = rig.part("Tail", V(0.3, 0.3, 1.4), at(0, -0.9, 0.95, -30, 0, 0), skin)
		rig.weld(torso, tail)
		rig.weld(torso, rig.part("TailTip", V(0.5, 0.5, 0.5), at(0, -1.25, 1.6, 45, 0, 45), glow, NEON))

		local head = rig.part("Head", V(1.6, 1.3, 1.4), at(0, 1.15, -0.1), skin)
		rig.joint(torso, head, V(0, 0.5, 0), "Neck", { Kind = "head" })
		for _, side in { -1, 1 } do
			rig.weld(head, rig.part("Horn", V(0.35, 0.9, 0.35), at(side * 0.55, 2.05, -0.1, 0, 0, -side * 25), dark))
			rig.weld(head, rig.part("Eye", V(0.35, 0.3, 0.12), at(side * 0.35, 1.3, -0.82), Color3.fromRGB(255, 240, 120), NEON))
		end
		rig.weld(head, rig.part("Grin", V(0.8, 0.12, 0.1), at(0, 0.85, -0.82), glow, NEON))
		embers(head, glow, 4, 0.25)

		for _, side in { -1, 1 } do
			local arm = rig.part("Arm", V(0.5, 1.3, 0.5), at(side * 1.15, -0.45, 0), skin)
			rig.joint(torso, arm, V(side * 1.15, 0.25, 0), "Shoulder", { Kind = "arm", Side = side })
			rig.weld(arm, rig.part("Claw", V(0.6, 0.4, 0.6), at(side * 1.15, -1.2, -0.1), dark))
		end
	end,
}

-- A floating crystal with shards that orbit around it.
DESIGNS.shardSprite = {
	height = 5,
	stride = 3,
	build = function(rig, root, def)
		local crystal = def.color
		local core = rig.part("Head", V(1.4, 2.2, 1.4), at(0, 0.4, 0), crystal, GLASS, 0.1)
		rig.joint(root, core, V(0, 0.4, 0), "Float", { Kind = "float", Amp = 0.5, Speed = 2 })
		rig.weld(core, rig.part("Top", V(0.9, 1.3, 0.9), at(0, 2.05, 0, 0, 45, 0), crystal, GLASS, 0.1))
		rig.weld(core, rig.part("Bottom", V(0.8, 1.2, 0.8), at(0, -1.25, 0, 0, 45, 0), crystal, GLASS, 0.1))
		local heart = rig.part("Heart", V(0.7, 1.2, 0.7), at(0, 0.4, 0), Color3.fromRGB(230, 210, 255), NEON)
		rig.weld(core, heart)
		light(heart, crystal, 12, 1.5)
		for _, x in { -0.3, 0.3 } do
			rig.weld(core, rig.part("Eye", V(0.25, 0.35, 0.1), at(x, 0.8, -0.73), Color3.new(1, 1, 1), NEON))
		end
		local orbit = rig.part("Orbit", V(0.2, 0.2, 0.2), at(0, 0.4, 0), crystal, nil, 1)
		rig.joint(core, orbit, V(0, 0.4, 0), "Orbit", { Kind = "spin", Speed = 1.6 })
		for i = 0, 2 do
			local angle = i * math.pi * 2 / 3
			rig.weld(orbit, rig.part("Shard", V(0.45, 1.4, 0.45), at(math.cos(angle) * 1.7, 0.4, math.sin(angle) * 1.7, 0, 45, 15), crystal, GLASS, 0.05))
		end
	end,
}

-- Boss 1: a huge knuckle-walking boulder with a heavy jaw.
DESIGNS.boss1 = {
	height = 10,
	stride = 6,
	build = function(rig, root, def)
		local stone = def.color
		local moss = Color3.fromRGB(88, 140, 64)
		for _, side in { -1, 1 } do
			local leg = rig.part("Leg", V(2.6, 3, 2.6), at(side * 2.3, -4, 0.5), Build.vary(stone, Random.new(4)))
			rig.joint(root, leg, V(side * 2.3, -2.8, 0.5), "Hip", { Kind = "leg", Side = side })
		end
		local torso = rig.part("Torso", V(8, 5.5, 7), at(0, 0.2, 0.3), stone)
		rig.joint(root, torso, V(0, -2.5, 0.3), "Body", { Kind = "body" })
		rig.weld(torso, rig.part("Facet", V(6.2, 5, 6.2), at(0, 0.8, 0.6, 0, 45, 0), Build.vary(stone, Random.new(5))))
		rig.weld(torso, rig.part("Moss", V(6, 0.8, 5), at(0, 3.25, 0.6, 0, 8, 0), moss))
		rig.weld(torso, rig.part("BackRock", V(2.2, 2.6, 2.2), at(-1.6, 3.4, 2, 20, 30, 15), Build.vary(stone, Random.new(6))))
		rig.weld(torso, rig.part("BackRock", V(1.6, 2, 1.6), at(1.8, 3.3, 1.4, -15, 10, -20), Build.vary(stone, Random.new(7))))

		local head = rig.part("Head", V(6.4, 1.6, 2), at(0, 2.5, -3), Build.vary(stone, Random.new(8), 0.05))
		rig.weld(torso, head)
		for _, side in { -1, 1 } do
			rig.weld(head, rig.part("Eye", V(1.1, 0.7, 0.3), at(side * 1.5, 1.5, -3.6), Color3.fromRGB(255, 70, 50), NEON))
		end
		local jaw = rig.part("Jaw", V(6, 1.8, 3), at(0, -1.4, -3.2), Build.vary(stone, Random.new(9), 0.06))
		rig.joint(torso, jaw, V(0, -0.8, -1.8), "Jaw", { Kind = "jaw" })
		for i = -1.5, 1.5, 1 do
			rig.weld(jaw, rig.part("Tooth", V(0.6, 0.9, 0.6), at(i * 1.5, -0.2, -4.3), Color3.fromRGB(226, 218, 196)))
		end

		for _, side in { -1, 1 } do
			local arm = rig.part("Arm", V(2.4, 6, 2.4), at(side * 5, -0.8, -0.5), stone)
			rig.joint(torso, arm, V(side * 5, 2, -0.5), "Shoulder", { Kind = "arm", Side = side })
			rig.weld(arm, rig.part("Fist", V(3.2, 3, 3.2), at(side * 5, -4, -0.8, 0, 20, 0), Build.vary(stone, Random.new(10))))
			rig.weld(arm, rig.part("Moss", V(2.6, 0.5, 2.6), at(side * 5, 2.2, -0.5), moss))
		end
	end,
}

-- Boss 2: a molten giant in a crust of cooled slag, wearing a spiked crown.
DESIGNS.boss2 = {
	height = 12,
	stride = 6.5,
	build = function(rig, root, def)
		local crust = Color3.fromRGB(58, 40, 36)
		local lava = Color3.fromRGB(255, 120, 40)
		for _, side in { -1, 1 } do
			local leg = rig.part("Leg", V(3, 4, 3), at(side * 2.6, -4.5, 0), crust)
			rig.joint(root, leg, V(side * 2.6, -3, 0), "Hip", { Kind = "leg", Side = side })
		end
		local torso = rig.part("Torso", V(8, 6, 6), at(0, 0, 0), def.color)
		rig.joint(root, torso, V(0, -2.5, 0), "Body", { Kind = "body" })
		rig.weld(torso, rig.part("Plate", V(7, 5, 6.4), at(0, 0.4, 0, 0, 0, 0), crust))
		for _, seam in { { -2, 15 }, { 0.6, -10 }, { 2.4, 20 } } do
			rig.weld(torso, rig.part("Seam", V(0.3, 4.6, 0.2), at(seam[1], 0.4, -3.25, 0, 0, seam[2]), lava, NEON))
		end
		local belly = rig.part("Belly", V(2.4, 2.4, 0.2), at(0, -0.6, -3.25, 0, 0, 45), lava, NEON)
		rig.weld(torso, belly)
		light(belly, lava, 22, 2)
		rig.weld(torso, rig.part("Skirt", V(9, 2, 8), at(0, -2.8, 0), crust))
		rig.weld(torso, rig.part("SkirtGlow", V(9.2, 0.3, 8.2), at(0, -3.7, 0), lava, NEON))

		local head = rig.part("Head", V(3.6, 3, 3.2), at(0, 4.6, -0.3), def.color)
		rig.joint(torso, head, V(0, 3, -0.3), "Neck", { Kind = "head" })
		for _, side in { -1, 1 } do
			rig.weld(head, rig.part("Eye", V(0.8, 0.5, 0.2), at(side * 0.8, 4.9, -1.95), Color3.fromRGB(255, 240, 160), NEON))
		end
		rig.weld(head, rig.part("Mouth", V(1.6, 0.25, 0.2), at(0, 3.9, -1.95), lava, NEON))
		for i = -2, 2 do
			local h = 1.8 - math.abs(i) * 0.3
			rig.weld(head, rig.part("Spike", V(0.55, h, 0.55), at(i * 0.65, 6.1 + h / 2, -0.3, 0, 45, i * 8), crust))
			rig.weld(head, rig.part("SpikeTip", V(0.4, 0.4, 0.4), at(i * 0.65 + i * 0.02, 6.2 + h, -0.3, 45, 0, 45), lava, NEON))
		end
		embers(head, lava, 6, 0.4)

		for _, side in { -1, 1 } do
			local arm = rig.part("Arm", V(2.4, 6.5, 2.4), at(side * 5.4, 0, 0), crust)
			rig.joint(torso, arm, V(side * 5.4, 2.6, 0), "Shoulder", { Kind = "arm", Side = side })
			local fist = rig.part("Fist", V(3, 2.6, 3), at(side * 5.4, -3.6, -0.3), def.color)
			rig.weld(arm, fist)
			rig.weld(arm, rig.part("Knuckles", V(3.1, 0.4, 0.3), at(side * 5.4, -3.2, -1.85), lava, NEON))
			embers(fist, lava, 3, 0.35)
		end
	end,
}

-- Boss 3: a four-legged stag made of pale stone with crystal antlers.
DESIGNS.boss3 = {
	height = 14,
	stride = 7,
	build = function(rig, root, def)
		local hide = def.color
		local hoof = Color3.fromRGB(70, 66, 96)
		local prism = Color3.fromRGB(180, 220, 255)
		local glow = Color3.fromRGB(220, 200, 255)
		for _, leg in { { -1.7, -2.8, 1 }, { 1.7, -2.8, -1 }, { -1.7, 4.4, -1 }, { 1.7, 4.4, 1 } } do
			local part = rig.part("Leg", V(1.3, 6.4, 1.3), at(leg[1], -3.8, leg[2]), Build.vary(hide, Random.new(11), 0.05))
			rig.joint(root, part, V(leg[1], -0.8, leg[2]), "Hip", { Kind = "leg", Side = leg[3] })
			rig.weld(part, rig.part("Hoof", V(1.5, 0.9, 1.5), at(leg[1], -7.05, leg[2]), hoof))
		end
		local torso = rig.part("Torso", V(5, 4.5, 9), at(0, 0.5, 0.8), hide)
		rig.joint(root, torso, V(0, -0.5, 0.8), "Body", { Kind = "body" })
		for i = 0, 3 do
			rig.weld(torso, rig.part("Spine", V(0.6, 1.6 - i * 0.2, 0.6), at(0, 3.2, -1.6 + i * 2, 20, 45, 0), prism, GLASS, 0.1))
		end
		rig.weld(torso, rig.part("Tail", V(0.8, 1.6, 0.8), at(0, 1.8, 5.6, -40, 0, 0), glow, NEON))
		rig.weld(torso, rig.part("Neck", V(2, 4.2, 2), at(0, 3.6, -3.6, -25, 0, 0), hide))

		local head = rig.part("Head", V(2.4, 2.2, 3.4), at(0, 5.8, -5.3), hide)
		rig.joint(torso, head, V(0, 4.8, -4.2), "Neck", { Kind = "head" })
		rig.weld(head, rig.part("Snout", V(1.6, 1.4, 1.6), at(0, 5.4, -7.2), Build.vary(hide, Random.new(12), 0.06)))
		rig.weld(head, rig.part("Nose", V(0.6, 0.4, 0.3), at(0, 5.7, -8.05), hoof))
		for _, side in { -1, 1 } do
			rig.weld(head, rig.part("Eye", V(0.15, 0.4, 0.6), at(side * 1.25, 6.1, -5.8), Color3.fromRGB(120, 230, 255), NEON))
			rig.weld(head, rig.part("Ear", V(0.4, 1.2, 0.3), at(side * 1.5, 6.9, -4.4, 0, 0, side * -50), hide))
			-- Crystal antlers: a main beam with three tines.
			local beam = CFrame.new(side * 1.0, 6.9, -5) * CFrame.Angles(0, 0, math.rad(-side * 30))
			rig.weld(head, rig.part("Antler", V(0.5, 4.2, 0.5), beam * CFrame.new(0, 2.1, 0), prism, GLASS, 0.05))
			for t = 1, 3 do
				local tine = beam * CFrame.new(0, t * 1.15, 0) * CFrame.Angles(math.rad(-25), 0, math.rad(side * 45)) * CFrame.new(0, 0.9, 0)
				rig.weld(head, rig.part("Tine", V(0.35, 1.8, 0.35), tine, prism, GLASS, 0.05))
				rig.weld(head, rig.part("TineTip", V(0.3, 0.3, 0.3), tine * CFrame.new(0, 0.9, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), glow, NEON))
			end
		end
		light(head, prism, 24, 1.6)
	end,
}

local function fallback(rig: Build.Rig, root: BasePart, def: any)
	local body = rig.part("Head", def.size * 0.9, CFrame.identity, def.color)
	rig.joint(root, body, V(0, 0, 0), "Body", { Kind = "body" })
	for _, x in { -0.5, 0.5 } do
		rig.weld(body, rig.part("Eye", V(0.4, 0.4, 0.2), at(x * def.size.X * 0.3, def.size.Y * 0.15, -def.size.Z * 0.46), Color3.fromRGB(255, 220, 120), NEON))
	end
end

-- Adds the visible body to an enemy model whose invisible root is already
-- placed. `designId` is the enemy id from Config.Enemies, or "boss<zone>".
function EnemyModels.dress(model: Model, root: BasePart, designId: string, def: any)
	if Build.attachAsset(model, root, { "Enemies", designId }, def.size.Y, true) then
		model:SetAttribute("Stride", def.size.Y * 0.5)
		return
	end
	local design = DESIGNS[def.designId or designId]
	if not design then
		fallback(Build.rig(model, root, 1), root, def)
		model:SetAttribute("Stride", 2)
		return
	end
	local scale = def.size.Y / design.height
	design.build(Build.rig(model, root, scale), root, def)
	model:SetAttribute("Stride", design.stride * scale)
end

return EnemyModels
