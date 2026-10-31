--!strict
-- The Wardrobe tab: every cosmetic, with a 3D preview on your own golem or
-- rider. A paid cosmetic is always previewed before its Buy button appears,
-- and buying opens Roblox's own purchase prompt for that exact item. There
-- are no random boxes: what you see is what you get.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CosmeticLooks = require(Shared:WaitForChild("CosmeticLooks"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local State = require(script.Parent:WaitForChild("State"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local Icons = require(script.Parent:WaitForChild("Icons"))

local Wardrobe = {}

local player = Players.LocalPlayer

local PREVIEW_HEIGHT = 240
local SPIN_SPEED = 0.6 -- radians per second

local previewId: string? = nil
local viewport: ViewportFrame? = nil
local camera: Camera? = nil
local trailBand: Frame? = nil
local builtKey = ""
local builtSource: Instance? = nil
local focus = { center = Vector3.zero, radius = 10, look = Vector3.new(0, 0, -1) }
local angle = 0

---------------------------------------------------------------- preview

local function golemModel(): Model?
	local folder = workspace:FindFirstChild("Golems")
	local model = folder and folder:FindFirstChild(player.Name .. "_Golem")
	return if model and model:IsA("Model") then model else nil
end

-- A still copy that's safe to show: no scripts, sounds, name tags or trails.
local function stillCopy(source: Model): Model?
	source.Archivable = true -- characters aren't copyable by default
	local copy = source:Clone()
	if not copy then
		return nil
	end
	for _, item in copy:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Sound") or item:IsA("BillboardGui") or item:IsA("Trail") then
			item:Destroy()
		elseif item:IsA("Humanoid") then
			item.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	return copy
end

-- Recolors a golem copy as if it wore `skinId`.
local function applySkin(model: Model, data: any, skinId: string?)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local slot = part:GetAttribute("LookSlot")
			if type(slot) == "string" then
				local color, material =
					CosmeticLooks.partLook(data.golem.parts[slot], part:GetAttribute("LookShade") :: number?, skinId)
				part.Color = color
				part.Material = material
			elseif part:GetAttribute("LookAccent") then
				part.Color = CosmeticLooks.accent(skinId)
			end
		end
	end
end

local function frame(model: Model)
	local cframe, size = model:GetBoundingBox()
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	local look = if root and root:IsA("BasePart") then root.CFrame.LookVector else Vector3.new(0, 0, -1)
	local flat = Vector3.new(look.X, 0, look.Z)
	focus.center = cframe.Position
	focus.radius = math.max(size.X, size.Y, size.Z)
	focus.look = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	angle = 0
end

-- Builds what the preview shows: the previewed cosmetic, or your golem as it is.
local function build(data: any)
	local vp = viewport
	if not vp then
		return
	end
	for _, child in vp:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") then
			child:Destroy()
		end
	end
	local cosmetic = previewId and Config.Cosmetics[previewId]
	local slot = if cosmetic then cosmetic.slot else nil
	local shown: Model? = nil

	if slot == "pet" and previewId then
		local pet = Instance.new("Model")
		CosmeticLooks.buildPet(previewId, pet, CFrame.new(), 1)
		shown = pet
	elseif slot == "outfit" and player.Character then
		shown = stillCopy(player.Character)
		if shown then
			CosmeticLooks.dress(shown, previewId)
		end
	else
		local source = golemModel()
		shown = if source then stillCopy(source) else nil
		if shown then
			local skinId = if slot == "skin" then previewId else Stats.equippedCosmetic(data, "skin")
			applySkin(shown, data, skinId)
		end
	end

	if trailBand then
		local trail = cosmetic and cosmetic.trail
		trailBand.Visible = trail ~= nil
		local gradient = trailBand:FindFirstChildOfClass("UIGradient")
		if trail and gradient then
			gradient.Color = ColorSequence.new(trail.colors[1], trail.colors[2])
		end
	end
	if shown then
		shown.Parent = vp
		frame(shown)
	end
end

local function ensureViewport(): ViewportFrame
	if viewport then
		return viewport
	end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview"
	vp.Size = UDim2.new(1, -12, 1, -12)
	vp.Position = UDim2.fromOffset(6, 6)
	vp.BackgroundColor3 = Color3.fromRGB(44, 52, 76)
	vp.Ambient = Color3.fromRGB(150, 150, 160)
	vp.LightColor = Color3.fromRGB(255, 245, 230)
	vp.LightDirection = Vector3.new(-1, -2, -1)
	Ui.corner(vp, 8)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam

	-- A ribbon of the trail's colors along the bottom, for trail previews.
	local band = Instance.new("Frame")
	band.Name = "TrailBand"
	band.AnchorPoint = Vector2.new(0.5, 1)
	band.Position = UDim2.new(0.5, 0, 1, -10)
	band.Size = UDim2.new(0.8, 0, 0, 14)
	band.BorderSizePixel = 0
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.Visible = false
	band.Parent = vp
	Ui.corner(band, 7)
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new(0, 0.85)
	gradient.Parent = band

	viewport, camera, trailBand = vp, cam, band

	RunService.RenderStepped:Connect(function(dt: number)
		if not vp.Parent or not camera then
			return
		end
		angle = (angle + dt * SPIN_SPEED) % (math.pi * 2)
		local direction = CFrame.Angles(0, angle, 0):VectorToWorldSpace(focus.look)
		local distance = focus.radius * 1.6
		camera.CFrame =
			CFrame.lookAt(focus.center + direction * distance + Vector3.new(0, focus.radius * 0.25, 0), focus.center)
	end)
	return vp
end

-- Menus clears the list on every refresh; keep the preview alive across it.
function Wardrobe.detach()
	if viewport then
		viewport.Parent = nil
	end
end

local function previewKey(data: any): string
	local key = previewId or "-"
	for _, entry in Config.CosmeticSlots do
		key ..= ":" .. (Stats.equippedCosmetic(data, entry.id) or "-")
	end
	for _, slot in Config.SlotOrder do
		key ..= ":" .. (data.golem.parts[slot] or "-")
	end
	return key
end

---------------------------------------------------------------- list

local function howToEarn(unlock: any): string
	if unlock.kind == "boss" then
		return `Defeat {Config.Bosses[unlock.zone].displayName}`
	elseif unlock.kind == "awaken" then
		return if unlock.count == 1 then "Awaken your golem once" else `Awaken {unlock.count} times`
	elseif unlock.kind == "zoneSet" then
		return `Find every artifact in {Config.Zones[unlock.zone].name}`
	elseif unlock.kind == "level" then
		return `Reach level {unlock.level}`
	elseif unlock.kind == "streak" then
		return `Play {unlock.days} days in a row.`
	elseif unlock.kind == "tutorial" then
		return "Finish the tutorial"
	end
	return "Earn it by playing"
end

-- Which kind of cosmetic the card grid shows.
local shownSlot = Config.CosmeticSlots[1].id

local function cosmeticCard(grid: Instance, data: any, id: string, order: number, showPreview: (string?) -> ())
	local cosmetic = Config.Cosmetics[id]
	local owned = Stats.ownsCosmetic(data, id)
	local wearing = Stats.equippedCosmetic(data, cosmetic.slot) == id
	local isPreviewed = previewId == id
	local look: Ui.Action = {
		text = "Look",
		style = "secondary",
		onClick = function()
			showPreview(id)
		end,
	}
	local line: string
	local stat = cosmetic.description
	local buttons: { Ui.Action }
	if owned then
		line = if wearing then "Wearing" else "Yours"
		buttons = {
			{
				text = if wearing then "Remove" else "Wear",
				style = if wearing then "secondary" else "primary",
				onClick = function()
					if wearing then
						State.request("unequipCosmetic", cosmetic.slot)
					else
						State.request("equipCosmetic", id)
					end
				end,
			},
		}
		if not isPreviewed then
			table.insert(buttons, 1, look)
		end
	elseif cosmetic.unlock then
		local current, needed = Stats.cosmeticProgress(data, id)
		line = "Free to earn"
		stat = howToEarn(cosmetic.unlock) .. (if needed > 1 then ` ({current} / {needed})` else "")
		buttons = { look }
	elseif (cosmetic.passId or 0) > 0 then
		-- Preview first, then the Buy button for that same item.
		line = "Looks only"
		buttons = {
			{
				text = tostring(cosmetic.price),
				style = "robux",
				onClick = function()
					if previewId == id then
						Remotes.Track:FireServer("purchasePrompted", "cosmetic", id)
						MarketplaceService:PromptGamePassPurchase(player, cosmetic.passId)
					else
						State.toast(`Trying {cosmetic.name}.\nTap the price again to buy.`)
						showPreview(id)
					end
				end,
			},
		}
		if not isPreviewed then
			table.insert(buttons, 1, look)
		end
	else
		line = "Coming soon"
		buttons = { look }
	end
	local card = Ui.card(grid, {
		title = cosmetic.name,
		line = line,
		icon = "wardrobe",
		stat = stat,
		statColor = if owned then Ui.Colors.good else Ui.Colors.quiet,
		color = if isPreviewed then Ui.Colors.gold elseif owned then Ui.Styles.primary else Ui.Headers.wardrobe,
		dark = Ui.Colors.card,
		ticked = wearing,
		order = order,
		buttons = buttons,
	})
	-- A lock on items you haven't got yet (they stay readable).
	if not owned then
		local lock = Icons.create(card, "lock", 28, UDim2.fromOffset(6, 6))
		lock.ZIndex = card.ZIndex + 4
	end
end

function Wardrobe.render(list: ScrollingFrame, snap: any, nextOrder: () -> number, refresh: () -> ())
	local data = snap.data

	local function showPreview(id: string?)
		previewId = id
		if id then
			Remotes.Track:FireServer("itemPreviewed", "cosmetic", id)
		end
		refresh()
	end

	-- The preview, at the top, in a framed panel.
	local holder = Instance.new("Frame")
	holder.Name = "PreviewHolder"
	holder.Size = UDim2.new(1, -8, 0, PREVIEW_HEIGHT)
	holder.LayoutOrder = nextOrder()
	holder.Parent = list
	Ui.corner(holder, 14)
	local rim = Ui.surface(holder, "studs", { tint = Ui.Colors.card })
	rim.Color = Ui.Colors.gold
	rim.Thickness = 4
	local vp = ensureViewport()
	vp.Parent = holder
	local source = if previewId and Config.Cosmetics[previewId].slot == "outfit" then player.Character else golemModel()
	local key = previewKey(data)
	if key ~= builtKey or source ~= builtSource then
		builtKey, builtSource = key, source
		build(data)
	end
	local previewing = previewId and Config.Cosmetics[previewId]
	Ui.label(
		holder,
		if previewing then previewing.name else "Your golem",
		UDim2.new(1, -120, 0, 30),
		UDim2.fromOffset(16, 12),
		{ ZIndex = 2, Title = true, TextSize = Ui.TextSize.big }
	)
	if previewing then
		local back = Ui.button(holder, "Back", UDim2.fromOffset(96, 48), UDim2.new(1, -106, 0, 10), true, function()
			showPreview(nil)
		end, "secondary")
		back.ZIndex = 2
	end

	local options = {}
	for _, entry in Config.CosmeticSlots do
		table.insert(options, { id = entry.id, text = (string.gsub(entry.name, "^Golem ", "")) })
	end
	Ui.toggles(list, nextOrder(), options, shownSlot, function(id: string)
		shownSlot = id
		refresh()
	end)

	for _, entry in Config.CosmeticSlots do
		if entry.id ~= shownSlot then
			continue
		end
		local worn = Stats.equippedCosmetic(data, entry.id)
		Ui.heading(list, nextOrder(), entry.name, "wardrobe")
		if worn then
			Ui.item(list, nextOrder(), {
				title = `Wearing {Config.Cosmetics[worn].name}`,
				icon = "tick",
			})
		end
		local grid = Ui.grid(list, nextOrder(), Ui.CardSize)
		local index = 0
		for _, id in Config.CosmeticOrder do
			if Config.Cosmetics[id].slot == entry.id then
				index += 1
				cosmeticCard(grid, data, id, index, showPreview)
			end
		end
	end
	Ui.item(list, nextOrder(), {
		title = "Fair play",
		subtitle = "Looks never change your power.\nBuy the look you tried. Nothing random.",
		icon = "guide",
	})
end

return Wardrobe
