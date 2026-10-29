-- Exercise the real CosmeticService purchase handler with a mocked
-- MarketplaceService. No Roblox purchase or account is involved.
do
	local config = table.clone(Config)
	config.Cosmetics = {
		frost = { name = "Frost", slot = "golem", passId = 3001 },
	}
	config.CosmeticOrder = { "frost" }

	local function signal()
		local callbacks = {}
		return {
			Connect = function(_, callback)
				table.insert(callbacks, callback)
			end,
			Fire = function(_, ...)
				for _, callback in callbacks do
					callback(...)
				end
			end,
		}
	end

	local purchased, loaded, changed = signal(), signal(), signal()
	local ownership = {}
	local ownershipCalls, events, notifications = 0, {}, {}
	local profiles = {}
	local marketplace = {
		PromptGamePassPurchaseFinished = purchased,
		UserOwnsGamePassAsync = function(_, userId, passId)
			assert(userId == 42 and passId == 3001)
			ownershipCalls += 1
			local response = ownership[passId]
			if type(response) == "table" then
				response = table.remove(response, 1)
			end
			if response == "error" then
				error("simulated marketplace outage")
			end
			return response == true
		end,
	}
	local service = loadCosmeticService({
		Config = config,
		CosmeticLooks = { dress = function() end },
		Remotes = {
			Notify = {
				FireClient = function(_, player, kind, message)
					table.insert(notifications, { player = player, kind = kind, message = message })
				end,
			},
		},
		Stats = {},
		ActionService = { register = function() end },
		AnalyticsService = { custom = function() end },
		DataService = {
			ProfileLoaded = loaded,
			Changed = changed,
			get = function(player)
				return profiles[player]
			end,
			update = function(player, fn)
				assert(profiles[player], "only loaded profiles can be updated")
				fn(profiles[player])
			end,
		},
		Events = {
			fire = function(...)
				table.insert(events, { ... })
			end,
			connect = function() end,
		},
		GolemService = { get = function() return nil end },
	}, {
		GetService = function(_, name)
			if name == "MarketplaceService" then
				return marketplace
			end
			return { WaitForChild = function() return {} end }
		end,
	}, {
		spawn = function(fn, ...)
			fn(...)
		end,
		wait = function() end,
	})
	service.start()

	local player = { UserId = 42, Parent = {} }
	profiles[player] = { cosmetics = { owned = {}, equipped = {} } }
	purchased:Fire(player, 3001, false)
	purchased:Fire(player, -1, true)
	assert(ownershipCalls == 0, "cancelled or unknown prompts never check ownership")
	purchased:Fire(player, 3001, true)
	assert(
		ownershipCalls == 3 and not profiles[player].cosmetics.owned.frost,
		"unowned cosmetic cannot be saved from a prompt callback"
	)
	assert(#events == 0 and #notifications == 0, "unverified cosmetics have no side effects")

	ownership[3001] = { "error", false, true }
	purchased:Fire(player, 3001, true)
	assert(ownershipCalls == 6, "fresh cosmetic purchases retry ownership")
	assert(
		profiles[player].cosmetics.owned.frost and profiles[player].cosmetics.equipped.golem == "frost",
		"confirmed cosmetic is granted and equipped"
	)
	assert(#events == 1 and events[1][3] == "cosmetic" and events[1][4] == "frost")
	assert(#notifications == 1, "confirmed cosmetic is announced once")

	ownership[3001] = true
	purchased:Fire(player, 3001, true)
	assert(#events == 1 and #notifications == 1, "duplicate prompt cannot grant twice")
	player.Parent = nil
	purchased:Fire(player, 3001, true)
	assert(#events == 1, "departed player cannot receive a cosmetic grant")

	local unloaded = { UserId = 42, Parent = {} }
	purchased:Fire(unloaded, 3001, true)
	assert(#events == 1, "unloaded player cannot receive a cosmetic grant")
	print("cosmetic-service: ok")
end
