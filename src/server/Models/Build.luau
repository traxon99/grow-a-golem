--!strict
-- Small helpers for building low-poly models out of plain parts in code.
-- Everything here is visual: decoration parts never collide, get touched,
-- or show up in queries, so they can't block golems or confuse game logic.

local Build = {}

export type PartProps = {
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	name: string?,
}

-- An anchored, non-colliding decoration part.
function Build.part(parent: Instance, props: PartProps): Part
	local part = Instance.new("Part")
	part.Name = props.name or "Deco"
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Shape = props.shape or Enum.PartType.Block
	part.Transparency = props.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = parent
	return part
end

-- An upright cylinder (Roblox cylinders lie along X, so this stands it up).
function Build.cylinder(
	parent: Instance,
	height: number,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	return Build.part(parent, {
		size = Vector3.new(height, diameter, diameter),
		cframe = cframe * CFrame.Angles(0, 0, math.rad(90)),
		color = color,
		material = material,
		shape = Enum.PartType.Cylinder,
	})
end

-- Same color, a little lighter or darker, so repeated pieces don't look flat.
function Build.vary(color: Color3, rng: Random, amount: number?): Color3
	local h, s, v = color:ToHSV()
	local a = amount or 0.08
	return Color3.fromHSV(h, s, math.clamp(v + rng:NextNumber(-a, a), 0, 1))
end

-- A random tilt on every axis, for faceted rocks and crystals.
function Build.tumble(rng: Random, maxDegrees: number): CFrame
	local m = math.rad(maxDegrees)
	return CFrame.Angles(rng:NextNumber(-m, m), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-m, m))
end

-- Turns a decoration part into a moving body part: unanchored, massless,
-- and joined to `part0` with a Motor6D so the client can animate it.
-- `pivot` is the joint position in part0's space; the part hangs from it.
function Build.joint(part0: BasePart, part1: BasePart, pivot: CFrame, name: string): Motor6D
	part1.Anchored = false
	part1.Massless = true
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = pivot
	motor.C1 = part1.CFrame:ToObjectSpace(part0.CFrame * pivot)
	motor.Parent = part1
	return motor
end

-- Welds a decoration part to a moving body so it follows it.
function Build.weld(part0: BasePart, part1: BasePart)
	part1.Anchored = false
	part1.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part1
end

-- Optional original art. Templates are decoration-only; gameplay roots,
-- humanoids, seats and animation joints remain owned by the game.
-- A template's pivot is its attachment point; author it at scale 1.
function Build.attachAsset(parent: Instance, root: BasePart, path: { string }, scale: number, animate: boolean?): Model?
	local source: Instance? = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	for _, name in path do
		source = if source then source:FindFirstChild(name) else nil
	end
	if not source or not source:IsA("Model") or not source.Archivable then
		return nil
	end
	local model = source:Clone() :: Model
	local parts: { BasePart } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		elseif
			item:IsA("LuaSourceContainer")
			or item:IsA("Humanoid")
			or item:IsA("JointInstance")
			or item:IsA("Constraint")
		then
			item:Destroy()
		end
	end
	if #parts == 0 then
		model:Destroy()
		return nil
	end
	model:ScaleTo(scale)
	model:PivotTo(root.CFrame)
	local body: BasePart? = nil
	local head: BasePart? = nil
	if animate then
		for _, part in parts do
			if part.Name == "Body" or part.Name == "Torso" or part.Name == "Carapace" then
				body = part
			elseif part.Name == "Head" or part.Name == "Jaw" then
				head = part
			end
		end
	end
	for _, part in parts do
		-- Seats are forbidden in decorative art (the real rider seat is separate).
		if part:IsA("Seat") or part:IsA("VehicleSeat") then
			model:Destroy()
			return nil
		end
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		local kind: string? = nil
		if body then
			if part == body then
				kind = "body"
			elseif part == head then
				kind = if part.Name == "Jaw" then "jaw" else "head"
			elseif part.Name == "Fist" or part.Name == "Wing" then
				kind = "arm"
			elseif part.Name == "Leg" or part.Name == "Foot" or part.Name == "CrawlerLeg" then
				kind = "leg"
			end
		end
		if kind then
			local parentPart = if part == body then root else body :: BasePart
			local pivot = part.CFrame
				* CFrame.new(0, if kind == "arm" or kind == "leg" then part.Size.Y * 0.5 else 0, 0)
			local motor = Build.joint(parentPart, part, parentPart.CFrame:ToObjectSpace(pivot), "ArtJoint")
			motor:SetAttribute("Kind", kind)
			motor:SetAttribute("Side", if root.CFrame:PointToObjectSpace(part.Position).X < 0 then -1 else 1)
		else
			local parentPart = if body then body else root
			if head and (part.Name == "Eye" or part.Name == "Antler") then
				parentPart = head
			end
			Build.weld(parentPart, part)
		end
	end
	model.Parent = parent
	return model
end

export type Rig = {
	part: (
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?,
		transparency: number?
	) -> Part,
	joint: (part0: BasePart, part1: BasePart, pivot: Vector3, name: string, attributes: { [string]: any }) -> Motor6D,
	weld: (part0: BasePart, part1: BasePart) -> (),
}

-- Builds a jointed model around `root` from a design drawn at scale 1.
-- Offsets and pivots are in the root's space and get multiplied by `scale`.
-- Joint attributes tell the client animator what to do with each joint:
--   Kind = "body" | "head" | "leg" | "arm" | "jaw" | "spin" | "float"
--   Side = 1 or -1 (legs and arms on opposite sides swing in opposite phase)
--   Amp, Speed = optional strength and speed overrides
function Build.rig(model: Model, root: BasePart, scale: number, partAssets: { [string]: { string } }?): Rig
	local function place(offset: CFrame): CFrame
		return root.CFrame * (CFrame.new(offset.Position * scale) * offset.Rotation)
	end
	return {
		part = function(name, size, offset, color, material, transparency)
			local part = Build.part(model, {
				name = name,
				size = size * scale,
				cframe = place(offset),
				color = color,
				material = material,
				transparency = transparency,
			})
			part.Anchored = false
			part.Massless = true
			local path = partAssets and partAssets[name]
			if path and Build.attachAsset(part, part, path, scale) then
				part.Transparency = 1
			end
			return part
		end,
		joint = function(part0, part1, pivot, name, attributes)
			local pivotWorld = root.CFrame * CFrame.new(pivot * scale)
			local motor = Build.joint(part0, part1, part0.CFrame:ToObjectSpace(pivotWorld), name)
			for key, value in attributes do
				motor:SetAttribute(key, value)
			end
			return motor
		end,
		weld = Build.weld,
	}
end

return Build
