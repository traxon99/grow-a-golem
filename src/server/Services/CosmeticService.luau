--!strict
-- Golem skins, wizard outfits, pets and trails (Config.Cosmetics). Looks
-- only: nothing here changes stats. Each cosmetic is either earned by
-- playing (checked whenever data changes) or bought directly as a game pass
-- for that exact item. There are no random rewards of any kind here.
-- Owned cosmetics are saved in data.cosmetics.owned; what's worn is in
-- data.cosmetics.equipped[slot]. GolemService draws skins, pets and trails;
-- outfits are put on the rider's character here.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CosmeticLooks = require(Shared:WaitForChild("CosmeticLooks"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local ActionService = require(script.Parent.ActionService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)

local CosmeticService = {}

local cosmeticByPassId: { [number]: string } = {}
for id, cosmetic in Config.Cosmetics do
	if (cosmetic.passId or 0) > 0 then
		cosmeticByPassId[cosmetic.passId] = id
	end
end

-- A finished purchase prompt is not proof of ownership. Retry briefly
-- for a newly purchased pass, but never grant without Roblox confirmation.
local function confirmPassPurchase(player: Player, passId: number): boolean
	for attempt = 1, 3 do
		if not player.Parent then
			return false
		end
		local ok, has = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok and has == true then
			return true
		end
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	return false
end

-- Puts the equipped outfit on the rider (or takes it off).
local function dressRider(player: Player)
	local character = player.Character
	local data = DataService.get(player)
	if not character or not data then
		return
	end
	CosmeticLooks.dress(character, Stats.equippedCosmetic(data, "outfit"))
end

-- Gives a cosmetic. `how` is "earned", "bought" (just now, so it's put on
-- straight away) or "restored" (bought earlier, outside this server).
function CosmeticService.grant(player: Player, id: string, how: string)
	local cosmetic = Config.Cosmetics[id]
	local data = DataService.get(player)
	if not cosmetic or not data or data.cosmetics.owned[id] then
		return
	end
	local wear = how == "bought"
	DataService.update(player, function(d)
		d.cosmetics.owned[id] = true
		if wear then
			d.cosmetics.equipped[cosmetic.slot] = id
		end
	end)
	if wear then
		Remotes.Notify:FireClient(player, "message", `Now wearing: {cosmetic.name}!`)
		dressRider(player)
	elseif how == "earned" then
		Remotes.Notify:FireClient(player, "message", `New look: {cosmetic.name}!\nOpen Wardrobe to wear it.`)
		AnalyticsService.custom(player, "CosmeticUnlocked", 1, id)
	end
end

-- Grants every earnable cosmetic the player has reached.
local function checkEarned(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	for _, id in Config.CosmeticOrder do
		local cosmetic = Config.Cosmetics[id]
		if cosmetic.unlock and not data.cosmetics.owned[id] and Stats.cosmeticEarned(data, id) then
			CosmeticService.grant(player, id, "earned")
		end
	end
end

-- Cosmetics bought on the website or in another server.
local function checkPasses(player: Player)
	for passId, id in cosmeticByPassId do
		local ok, has = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok and has and player.Parent then
			CosmeticService.grant(player, id, "restored")
		end
	end
end

local function equip(player: Player, id: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(id) ~= "string" or not Config.Cosmetics[id] then
		return false, "Not ready"
	end
	if not Stats.ownsCosmetic(data, id) then
		return false, "You don't have that yet"
	end
	local cosmetic = Config.Cosmetics[id]
	DataService.update(player, function(d)
		d.cosmetics.equipped[cosmetic.slot] = id
	end)
	dressRider(player)
	return true, `Wearing {cosmetic.name}`
end

local function unequip(player: Player, slot: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(slot) ~= "string" or data.cosmetics.equipped[slot] == nil then
		return false, "Nothing to take off"
	end
	local cosmetic = Config.Cosmetics[data.cosmetics.equipped[slot]]
	DataService.update(player, function(d)
		d.cosmetics.equipped[slot] = nil
	end)
	dressRider(player)
	return true, if cosmetic then `Took off {cosmetic.name}` else "Taken off"
end

local function cheer(player: Player)
	local golem = GolemService.get(player)
	local data = DataService.get(player)
	if golem and data and Stats.equippedCosmetic(data, "pet") then
		golem.model:SetAttribute("Cheer", ((golem.model:GetAttribute("Cheer") :: number?) or 0) + 1)
	end
end

function CosmeticService.start()
	ActionService.register("equipCosmetic", equip)
	ActionService.register("unequipCosmetic", unequip)

	DataService.ProfileLoaded:Connect(function(player)
		checkEarned(player)
		task.spawn(checkPasses, player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			character:WaitForChild("HumanoidRootPart", 10)
			dressRider(player)
		end)
		if player.Character then
			dressRider(player)
		end
	end)
	DataService.Changed:Connect(checkEarned)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local id = cosmeticByPassId[passId]
		if not purchased or not id then
			return
		end
		task.spawn(function()
			if not confirmPassPurchase(player, passId) then
				return
			end
			local data = DataService.get(player)
			if not data or data.cosmetics.owned[id] then
				return
			end
			CosmeticService.grant(player, id, "bought")
			Events.fire("purchased", player, "cosmetic", id)
		end)
	end)

	-- The pet hops for every win.
	Events.connect("enemyDefeated", cheer)
	Events.connect("bossDefeated", cheer)
end

return CosmeticService
