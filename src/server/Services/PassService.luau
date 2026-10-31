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
local Events = require(script.Parent.Events)
local PolicyService = require(script.Parent.PolicyService)

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
	local passes: { [string]: boolean } = {}
	for key, pass in Config.GamePasses do
		if pass.id > 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			passes[key] = ok and has == true
		end
	end
	if player.Parent then
		-- A purchase may have been verified while these slower initial
		-- ownership lookups were running. Never overwrite a confirmed grant.
		local current = owned[player] or {}
		for key, has in passes do
			if current[key] ~= true then
				current[key] = has
			end
		end
		owned[player] = current
		DataService.markChanged(player)
	end
end

-- The prompt callback is not proof of payment. Roblox's ownership cache
-- can lag a fresh purchase, so retry briefly but always fail closed.
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

local function grantProduct(player: Player, key: string)
	local product = Config.Products[key]
	local data = DataService.get(player)
	local name = product.name
	if product.boost then
		local boost = product.boost
		if product.paidRandom and not PolicyService.paidRandomAllowed(player) then
			-- Paid random items are restricted for this player: never grant one.
			boost = product.restrictedAlternative
			name = `2x {boost} for {product.minutes} minutes.\n2x Luck unavailable for your account.`
		end
		DataService.update(player, function(d)
			local now = os.time()
			local current = math.max(d.boosts[boost] or 0, now)
			d.boosts[boost] = current + product.minutes * 60
		end)
	elseif product.packMinutes and data then
		-- A mineral pack is worth a few hours of mining in your best zone.
		local zone = Config.Zones[Stats.highestZone(data)]
		local minerals = {}
		for mineral, perMinute in zone.offlineMinerals do
			minerals[mineral] = perMinute * product.packMinutes * 3
		end
		DataService.addMinerals(player, minerals, "purchase")
	end
	Events.fire("purchased", player, "product", key)
	Remotes.Notify:FireClient(player, "message", `Thanks! {name} added.`)
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
	if Config.Products[key].paidRandom and not PolicyService.isReady(player) then
		-- Wait for the policy lookup so we know what we're allowed to grant.
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

-- When a boost runs out nothing in the save changes, so nudge the golem stats
-- and the client snapshot at that moment: the odds shown drop back right away.
local activeBoosts: { [Player]: string } = {}
local function watchBoosts()
	while true do
		task.wait(1)
		local now = os.time()
		for _, player in Players:GetPlayers() do
			local data = DataService.get(player)
			if data then
				local active = {}
				for boost, endsAt in data.boosts do
					if endsAt > now then
						table.insert(active, boost)
					end
				end
				table.sort(active)
				local signature = table.concat(active, ",")
				if activeBoosts[player] ~= nil and activeBoosts[player] ~= signature then
					DataService.markChanged(player)
				end
				activeBoosts[player] = signature
			end
		end
	end
end

function PassService.start()
	DataService.addProvider("passes", PassService.passes)
	task.spawn(watchBoosts)
	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(checkPasses, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		activeBoosts[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeyById[passId]
		if not purchased or not key then
			return
		end
		task.spawn(function()
			if not confirmPassPurchase(player, passId) or not DataService.get(player) then
				return
			end
			local passes = owned[player] or {}
			if passes[key] then
				return
			end
			passes[key] = true
			owned[player] = passes
			DataService.markChanged(player)
			Events.fire("purchased", player, "pass", key)
			Remotes.Notify:FireClient(player, "message", `Thanks! {Config.GamePasses[key].name} is active.`)
		end)
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return PassService
