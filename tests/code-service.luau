-- Redeemable codes (CodeService). The check script bundles the real Config
-- above this file and loads the real CodeService with its requires replaced
-- by the mocks below and a test-controlled os.clock/os.time.
do
	local function signal()
		local listeners = {}
		return {
			Connect = function(_, fn)
				table.insert(listeners, fn)
			end,
			Fire = function(_, ...)
				for _, fn in listeners do
					fn(...)
				end
			end,
		}
	end

	local clockNow = 0
	local timeNow = 1000
	local handlers = {}
	local granted = {}
	local fired = {}
	local datas = {}
	local removing = signal()

	local function fresh()
		return { codesRedeemed = {} }
	end

	local codeService = loadCodeService({
		Config = Config,
		ActionService = {
			register = function(name, fn)
				handlers[name] = fn
			end,
		},
		DataService = {
			get = function(player)
				return datas[player]
			end,
			update = function(player, fn)
				fn(datas[player])
			end,
			saveNow = function() end,
		},
		EconomyService = {
			grantFlat = function(player, reward, source)
				assert(source == "code", 'codes grant with source "code"')
				table.insert(granted, { player = player, reward = reward })
			end,
		},
		Events = {
			fire = function(name, player, code)
				table.insert(fired, { name = name, player = player, code = code })
			end,
		},
	}, {
		GetService = function()
			return {
				PlayerRemoving = removing,
				WaitForChild = function()
					return {}
				end,
			}
		end,
	}, function()
		return clockNow
	end, function()
		return timeNow
	end)
	codeService.start()
	local redeem = handlers.redeemCode
	assert(redeem, "redeemCode is registered")

	local nextId = 0
	local function join()
		nextId += 1
		local player = { UserId = nextId, DisplayName = "P" .. nextId }
		datas[player] = fresh()
		return player
	end

	------------------------------------------------------------------ normalize
	-- Exercised indirectly through redeem, since normalize() isn't exported:
	-- case, whitespace and punctuation are all handled before the lookup.
	do
		-- Every player's first-ever attempt starts with state.last = 0, so the
		-- clock must already be past the cooldown or that first call is itself
		-- read as "too soon after last=0".
		clockNow += Config.CodeLimits.cooldown + 1
		local p = join()
		local ok1 = redeem(p, "golem100")
		assert(ok1 == true, "lower-case matches the upper-cased key")
		clockNow += Config.CodeLimits.cooldown + 1
		local p2 = join()
		local ok2 = redeem(p2, "  GOLEM100  ")
		assert(ok2 == true, "surrounding whitespace is stripped")
		clockNow += Config.CodeLimits.cooldown + 1
		local p3 = join()
		local ok3, msg3 = redeem(p3, "GOLEM-100")
		assert(ok3 == false and msg3 ~= nil, "punctuation makes it an unknown code")
		clockNow += Config.CodeLimits.cooldown + 1
		local p4 = join()
		local ok4 = redeem(p4, string.rep("A", 100))
		assert(ok4 == false, "codes over 64 chars are rejected before lookup")
		clockNow += Config.CodeLimits.cooldown + 1
		local p5 = join()
		local ok5 = redeem(p5, 12345)
		assert(ok5 == false, "non-string input is rejected")
	end

	------------------------------------------------------------------ one-time
	do
		clockNow += 100
		local player = join()
		local ok, msg = redeem(player, "GOLEM100")
		assert(ok == true, "a valid, unused code redeems")
		assert(#granted > 0 and granted[#granted].player == player)
		assert(granted[#granted].reward.minerals.stone == 100)
		assert(datas[player].codesRedeemed.GOLEM100 ~= nil, "the code is marked used on this save")
		assert(#fired > 0 and fired[#fired].name == "codeRedeemed")

		clockNow += Config.CodeLimits.cooldown + 1
		local grantedBefore = #granted
		local ok2, msg2 = redeem(player, "GOLEM100")
		assert(ok2 == false, "the same code can't be redeemed twice by the same player")
		assert(msg2 ~= nil and #granted == grantedBefore, "a repeat attempt grants nothing")

		-- A different player can still redeem the same code once.
		clockNow += Config.CodeLimits.cooldown + 1
		local other = join()
		local ok3 = redeem(other, "GOLEM100")
		assert(ok3 == true, "codesRedeemed is tracked per player, not globally")
	end

	------------------------------------------------------------------ expiry
	do
		Config.Codes.EXPIRETEST = { reward = { xp = 10 }, expires = timeNow - 1 }
		clockNow += 100
		local player = join()
		local ok, msg = redeem(player, "EXPIRETEST")
		assert(ok == false, "an expired code is refused")
		assert(msg ~= nil and string.find(msg, "Code ended", 1, true) ~= nil)
		assert(datas[player].codesRedeemed.EXPIRETEST == nil, "nothing is marked used on expiry")

		Config.Codes.NOTYETEXPIRED = { reward = { xp = 10 }, expires = timeNow + 1000 }
		clockNow += Config.CodeLimits.cooldown + 1
		local ok2 = redeem(player, "NOTYETEXPIRED")
		assert(ok2 == true, "a code expiring in the future still redeems")
		Config.Codes.EXPIRETEST = nil
		Config.Codes.NOTYETEXPIRED = nil
	end

	------------------------------------------------------------------ unknown
	do
		clockNow += 100
		local player = join()
		local ok, msg = redeem(player, "NOSUCHCODE")
		assert(ok == false and msg ~= nil, "an unknown code is refused with a message")
	end

	------------------------------------------------------------------ cooldown
	do
		clockNow += 100
		local player = join()
		local ok1 = redeem(player, "NOSUCHCODE")
		assert(ok1 == false)
		-- Immediately retrying, inside the cooldown window, is told to wait
		-- rather than counted as another wrong guess.
		local ok2, msg2 = redeem(player, "GOLEM100")
		assert(ok2 == false and msg2 == "One moment...", "a retry inside the cooldown doesn't reach the code lookup")
	end

	----------------------------------------------------------------- lockout
	do
		clockNow += 100
		local player = join()
		for i = 1, Config.CodeLimits.maxFailures - 1 do
			local ok = redeem(player, "NOSUCHCODE" .. i)
			assert(ok == false)
			clockNow += Config.CodeLimits.cooldown + 1
		end
		-- The next failure crosses maxFailures and triggers the lockout.
		local okLock = redeem(player, "STILLWRONG")
		assert(okLock == false)
		clockNow += Config.CodeLimits.cooldown + 1
		local okDuring, msgDuring = redeem(player, "GOLEM100")
		assert(
			okDuring == false and string.find(msgDuring, "Too many tries") ~= nil,
			"locked out even with a good code"
		)

		-- After lockoutSeconds the lock clears and a good code redeems again.
		clockNow += Config.CodeLimits.lockoutSeconds + 1
		local okAfter = redeem(player, "GOLEM100")
		assert(okAfter == true, "the lock clears once lockoutSeconds has passed")
	end

	----------------------------------------------------------- success resets
	do
		clockNow += 100
		local player = join()
		for i = 1, Config.CodeLimits.maxFailures - 1 do
			redeem(player, "NOSUCHCODE" .. i)
			clockNow += Config.CodeLimits.cooldown + 1
		end
		-- One short of locking out, a success should reset the failure count
		-- rather than carry it toward a future lockout.
		local okGood = redeem(player, "ROCKSOLID")
		assert(okGood == true)
		clockNow += Config.CodeLimits.cooldown + 1
		local okNext, msgNext = redeem(player, "STILLBAD")
		assert(okNext == false and msgNext ~= "Too many tries." and not string.find(msgNext or "", "Too many tries"))
	end

	print("code-service: ok")
end
