--!strict
-- Game pass ownership and developer product receipts.
-- Pass ownership is checked live with Roblox and never stored in the save.
-- Developer products are granted once per receipt and saved before Roblox is
-- told the purchase went through.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local DataService = require(script.Parent.DataService)

local MAX_RECEIPTS_KEPT = 50

local PassService = {}

local owned: { [Player]: { [string]: boolean } } = {}

local passKeyById: { [number]: string } = {}
for key, pass in Config.GamePasses do
	if pass.id > 0 then
		passKeyById[pass.id] = key
	end
end
local productKeyById: { [number]: string } = {}
for key, product in Config.Products do
	if product.id > 0 then
		productKeyById[product.id] = key
	end
end

function PassService.owns(player: Player, key: string): boolean
	local passes = owned[player]
	return passes ~= nil and passes[key] == true
end

-- True once ownership has been checked with Roblox for this session.
function PassService.isReady(player: Player): boolean
	return owned[player] ~= nil
end

function PassService.passes(player: Player): { [string]: boolean }
	return table.clone(owned[player] or {})
end

local function checkPasses(player: Player)
	local passes = {}
	for key, pass in Config.GamePasses do
		if pass.id > 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			passes[key] = ok and has == true
		end
	end
	if player.Parent then
		owned[player] = passes
		DataService.markChanged(player)
	end
end

local function grantProduct(player: Player, key: string)
	local product = Config.Products[key]
	DataService.update(player, function(data)
		if product.boost then
			local now = os.time()
			local current = math.max(data.boosts[product.boost] or 0, now)
			data.boosts[product.boost] = current + product.minutes * 60
		elseif product.packMinutes then
			-- A mineral pack is worth a few hours of mining in your best zone.
			local zone = Config.Zones[Stats.highestZone(data)]
			for mineral, perMinute in zone.offlineMinerals do
				data.minerals[mineral] = (data.minerals[mineral] or 0) + perMinute * product.packMinutes * 3
			end
		end
	end)
	Remotes.Notify:FireClient(player, "message", `Thanks! {product.name} added.`)
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = productKeyById[receipt.ProductId]
	if not key then
		warn(`[PassService] Unknown product id {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	grantProduct(player, key)
	DataService.update(player, function(d)
		table.insert(d.receipts, receipt.PurchaseId)
		while #d.receipts > MAX_RECEIPTS_KEPT do
			table.remove(d.receipts, 1)
		end
	end)

	local session = DataService.getSession(player)
	if session and session.canSave and not DataService.saveNow(player) then
		-- Roblox will retry; the receipt id stops a double grant this session.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PassService.start()
	DataService.addProvider("passes", PassService.passes)
	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(checkPasses, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeyById[passId]
		if purchased and key and owned[player] then
			owned[player][key] = true
			DataService.markChanged(player)
			Remotes.Notify:FireClient(player, "message", `Thanks! {Config.GamePasses[key].name} is active.`)
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return PassService
