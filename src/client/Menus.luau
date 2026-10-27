--!strict
-- The menu window: a column of tab buttons on the left and one list window.
-- Each tab is a function that fills the list from the latest snapshot; the
-- open tab re-renders whenever the snapshot changes.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local State = require(script.Parent:WaitForChild("State"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Wardrobe = require(script.Parent:WaitForChild("Wardrobe"))

local Menus = {}

local player = Players.LocalPlayer

type Render = (list: ScrollingFrame, snap: any) -> ()

local function tierRank(tier: string?): number
	return if tier then (table.find(Config.TierOrder, tier) or 0) else 0
end

local function percent(chance: number): string
	return `{string.format("%.2f", chance * 100)}%`
end

-- One island's artifact odds at a given luck, per enemy and per boss.
local function oddsText(data: any, zoneId: number, luckMult: number): string
	local parts = {}
	for _, source in { "drop", "boss" } do
		local chance, _, unfound = Stats.artifactOdds(data, zoneId, source, luckMult)
		local spareChance, _, spares = Stats.spareOdds(data, zoneId, source, luckMult)
		local who = if source == "boss" then "boss" else "enemy"
		table.insert(
			parts,
			if unfound > 0
				then `{percent(chance)} per {who}`
				elseif spares then `{who} artifacts all found, {percent(spareChance)} per {who} for a spare copy`
				else `{who} artifacts all found`
		)
	end
	return table.concat(parts, ", ")
end

local function luckBoostEndsIn(data: any): number
	return math.max(((data.boosts or {}).luck or 0) - State.serverNow(), 0)
end

---------------------------------------------------------------- tabs

local function renderForge(list: ScrollingFrame, snap: any)
	local data = snap.data
	local stats = Stats.compute(data, State.context())
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	Ui.heading(list, nextOrder(), "Your golem")
	Ui.row(
		list,
		nextOrder(),
		`Health {stats.maxHealth}  ·  Damage {math.floor(stats.attackDamage)}`,
		`Mining {math.floor(stats.miningDamage)}  ·  Speed {math.floor(stats.walkSpeed)}`
			.. (if stats.fullSet then `  ·  Full {Config.Tiers[stats.fullSet].displayName} set bonus!` else "")
	)

	Ui.heading(list, nextOrder(), "Forge parts")
	for _, slot in Config.SlotOrder do
		local current = data.golem.parts[slot]
		local currentName = if current then Config.Tiers[current].displayName else "Bare stone"
		local nextTier = Config.TierOrder[tierRank(current) + 1]
		if nextTier then
			local cost = Stats.partCost(slot, nextTier)
			Ui.row(
				list,
				nextOrder(),
				`{Config.Slots[slot].displayName}: {currentName}`,
				`Next: {Config.Tiers[nextTier].displayName} for {Ui.costText(cost)}`,
				"Forge",
				Stats.canAfford(data, cost),
				function()
					State.request("craftPart", slot, nextTier)
				end
			)
		else
			Ui.row(list, nextOrder(), `{Config.Slots[slot].displayName}: {currentName}`, "Best tier forged")
		end
	end
	Ui.row(list, nextOrder(), "Tip", "Forge all five parts from the same tier for +15% health and damage.")
end

-- The co-op Golem Tower section of Travel (TowerService). Every reward shown
-- here is the fixed amount the server pays (Stats.towerWaveReward).
local function renderTower(list: ScrollingFrame, snap: any, start: number)
	local tower = snap.tower
	if not tower or not tower.enabled then
		return
	end
	local order = start
	local function nextOrder(): number
		order += 1
		return order
	end
	local name = Config.Tower.name
	local waves = Config.Tower.waves
	Ui.heading(list, nextOrder(), name)
	local run = tower.run
	if run then
		local route = (Config.Zones[run.route] :: any).name
		if run.state == "inviting" then
			if run.isLeader then
				local waiting = 0
				for _, member in run.members do
					if not member.accepted then
						waiting += 1
					end
				end
				Ui.row(
					list,
					nextOrder(),
					`{route} route: waiting for {waiting} to accept`,
					`The run starts when everyone accepts ({run.inviteLeft}s left).`,
					"Cancel",
					true,
					function()
						State.request("towerLeave")
					end
				)
			else
				local reward = Stats.towerRunReward(run.route)
				Ui.row(
					list,
					nextOrder(),
					`{run.leaderName} invites you: {route} route, {waves} waves`,
					`Full clear pays you {Ui.rewardText(reward)}. {run.inviteLeft}s left to answer.`,
					"Accept",
					true,
					function()
						State.request("towerAccept")
					end
				)
				Ui.row(list, nextOrder(), "Not this time", nil, "Decline", true, function()
					State.request("towerDecline")
				end)
			end
			return
		end
		local status = if run.state == "ended"
			then run.endText or "The run is over."
			elseif run.state == "break" then `Wave {run.wave + 1} of {waves} starts in a moment`
			else `Wave {run.wave} of {waves}: {run.remaining} enemies left`
		Ui.row(list, nextOrder(), `{route} route  ·  {run.cleared} / {waves} waves cleared`, status)
		if run.state ~= "ended" then
			local nextWave = math.min(run.wave + (if run.state == "break" then 1 else 0), waves)
			local reward = Stats.towerWaveReward(run.route, math.max(nextWave, 1))
			Ui.row(
				list,
				nextOrder(),
				`Clearing this wave pays {Ui.rewardText(reward)}`,
				"Leaving keeps what you've earned; you miss the waves you haven't cleared.",
				"Leave",
				true,
				function()
					State.request("towerLeave")
				end
			)
		end
		return
	end

	local data = snap.data
	local bossList = {}
	for wave in Config.Tower.bossWaves do
		table.insert(bossList, wave)
	end
	table.sort(bossList)
	local bossWaves = table.concat(bossList, " and ")
	if not tower.isLeader then
		Ui.row(
			list,
			nextOrder(),
			"Your party leader starts tower runs",
			`{waves} waves together, each one paid as you clear it.`
		)
		return
	end
	Ui.row(
		list,
		nextOrder(),
		if tower.partySize > 1 then `Climb with your party of {tower.partySize}` else "Climb solo, or with a party",
		`{waves} waves of one island's enemies, with its boss on waves {bossWaves}. Every cleared wave pays everyone.`
	)
	for _, zoneId in Config.ZoneOrder do
		local unlocked = Stats.zoneUnlocked(data, zoneId)
		if unlocked then
			local reward = Stats.towerRunReward(zoneId)
			Ui.row(
				list,
				nextOrder(),
				`{(Config.Zones[zoneId] :: any).name} route`,
				`Full clear: {Ui.rewardText(reward)}`,
				if tower.full then "Full" else "Start",
				not tower.full,
				function()
					State.request("towerStart", zoneId)
				end
			)
		end
	end
end

local function renderTravel(list: ScrollingFrame, snap: any)
	local data = snap.data
	local currentZone = if snap.golem then snap.golem.zoneId else 1
	Ui.heading(list, 1, "Islands")
	local inHub = currentZone == Config.HubZone
	Ui.row(
		list,
		2,
		Config.Hub.name,
		if inHub then "You are here" else "A safe island to show off your golem and meet other players",
		"Travel",
		not inHub,
		function()
			State.request("travel", Config.HubZone)
		end
	)
	for index, zoneId in Config.ZoneOrder do
		local zone = Config.Zones[zoneId]
		local unlocked, reason = Stats.zoneUnlocked(data, zoneId)
		local subtitle: string
		if zoneId == currentZone then
			subtitle = "You are here"
			if snap.golem and Config.Bosses[zoneId] then
				subtitle ..= if snap.golem.bossAlive
					then `  ·  {Config.Bosses[zoneId].displayName} is awake`
					else `  ·  boss returns in about {snap.golem.bossRespawnIn}s`
			end
		elseif unlocked then
			subtitle = if Stats.bossDefeated(data, zoneId) then "Boss defeated" else "Open"
		else
			subtitle = `Locked: {reason}`
		end
		Ui.row(list, index + 2, zone.name, subtitle, "Travel", unlocked and zoneId ~= currentZone, function()
			State.request("travel", zoneId)
		end)
	end
	renderTower(list, snap, 100)
end

local function renderArtifacts(list: ScrollingFrame, snap: any)
	local data = snap.data
	local stats = Stats.compute(data, State.context())
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	Ui.heading(
		list,
		nextOrder(),
		`Equipped {#data.artifacts.equipped} / {stats.artifactSlots}  ·  Found {Stats.artifactsFound(data)} / {#Config.ArtifactOrder}`
	)
	local boostLeft = luckBoostEndsIn(data)
	if boostLeft > 0 then
		Ui.row(
			list,
			nextOrder(),
			`2x Luck is on for {Ui.duration(boostLeft)}`,
			"The odds below already include it and drop back when it ends."
		)
	end

	local sourceHint = {
		drop = "Rare drop from enemies",
		boss = "Dropped by the zone boss",
		hidden = "A glowing relic hidden on the island",
	}
	for _, zoneId in Config.ZoneOrder do
		local complete = Stats.zoneSetComplete(data, zoneId)
		local found, total = Stats.zoneArtifactCount(data, zoneId)
		Ui.heading(
			list,
			nextOrder(),
			`{Config.Zones[zoneId].name}  {found} / {total}`
				.. (
					if complete
						then `  (set complete: {Ui.bonusText(Config.ZoneSetBonus)})`
						else `  ·  complete it for {Ui.bonusText(Config.ZoneSetBonus)}`
				)
		)
		-- The real odds, including luck, and how close bad-luck protection is.
		for _, source in { "drop", "boss" } do
			local chance, rollsLeft, unfound = Stats.artifactOdds(data, zoneId, source, stats.luckMult)
			if unfound > 0 then
				local who = if source == "boss" then "boss defeat" else "enemy defeated"
				Ui.row(
					list,
					nextOrder(),
					`Odds: {string.format("%.2f", chance * 100)}% per {who}`,
					`{unfound} left to find. One is guaranteed within {rollsLeft} more.`
				)
			else
				-- Everything from this source is found, so the same roll now
				-- gives spare copies to trade (see the Trade tab).
				local spareChance, spareLeft, spares = Stats.spareOdds(data, zoneId, source, stats.luckMult)
				if spares then
					local who = if source == "boss" then "boss defeat" else "enemy defeated"
					Ui.row(
						list,
						nextOrder(),
						`Spare copies: {string.format("%.2f", spareChance * 100)}% per {who}`,
						`All found here. A spare to trade is guaranteed within {spareLeft} more.`
					)
				end
			end
		end
		for _, id in Config.ArtifactOrder do
			local artifact = Config.Artifacts[id]
			if artifact.zone == zoneId then
				if data.artifacts.found[id] then
					local equipped = table.find(data.artifacts.equipped, id) ~= nil
					local spare = (data.artifacts.spares or {})[id] or 0
					local spareText = if spare > 0
						then `  ·  {spare} spare ({Stats.tradableSpares(data, id)} tradable)`
						else ""
					Ui.row(
						list,
						nextOrder(),
						artifact.name,
						Ui.bonusText(artifact.bonus) .. spareText,
						if equipped then "Unequip" else "Equip",
						true,
						function()
							State.request(if equipped then "unequipArtifact" else "equipArtifact", id)
						end
					)
				else
					Ui.row(list, nextOrder(), "???", sourceHint[artifact.source])
				end
			end
		end
	end
end

local function renderSkills(list: ScrollingFrame, snap: any)
	local data = snap.data
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	Ui.row(
		list,
		nextOrder(),
		`Skill points: {Stats.skillPointsAvailable(data)}`,
		"You earn 1 point per level.",
		"Reset",
		next(data.skills) ~= nil,
		function()
			State.request("respecSkills")
		end
	)
	Ui.row(list, nextOrder(), "Reset cost", Ui.costText(Config.SkillRespecCost))
	for _, branch in Config.SkillBranches do
		Ui.heading(list, nextOrder(), branch.displayName)
		for _, skillId in branch.nodes do
			local skill = Config.Skills[skillId]
			local extra = {}
			if next(skill.bonus) then
				table.insert(extra, Ui.bonusText(skill.bonus))
			end
			if skill.artifactSlots then
				table.insert(extra, `+{skill.artifactSlots} artifact slot`)
			end
			if skill.offlineHours then
				table.insert(extra, `+{skill.offlineHours}h offline mining`)
			end
			local learned = data.skills[skillId] == true
			local canLearn = Stats.canLearnSkill(data, skillId)
			Ui.row(
				list,
				nextOrder(),
				`{skill.name} ({skill.cost} pt)`,
				table.concat(extra, ", "),
				if learned then "Learned" else "Learn",
				canLearn and not learned,
				function()
					State.request("learnSkill", skillId)
				end
			)
		end
	end
end

local confirmAwakenUntil = 0
local confirmAscendUntil = 0
local function renderAwaken(list: ScrollingFrame, snap: any)
	local data = snap.data
	local level = Stats.levelForXp(data.golem.xp)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	Ui.heading(list, nextOrder(), `Awakenings: {data.awakening.count}  ·  Shards: {data.awakening.shards}`)
	local canAwaken = level >= Config.Awakening.minLevel
	local confirming = os.clock() < confirmAwakenUntil
	Ui.row(
		list,
		nextOrder(),
		if canAwaken
			then `Awaken now for {Stats.awakeningShards(level)} shards`
			else `Reach level {Config.Awakening.minLevel} to Awaken`,
		"Resets level, parts, skills, minerals, and bosses. Keeps artifacts, shards, and upgrades.",
		if confirming then "Tap to confirm" else "Awaken",
		canAwaken,
		function()
			if os.clock() < confirmAwakenUntil then
				confirmAwakenUntil = 0
				State.request("awaken")
			else
				confirmAwakenUntil = os.clock() + 4
				State.toast("Tap Awaken again to confirm")
				Menus.refresh()
			end
		end
	)
	Ui.row(list, nextOrder(), "Every Awakening", `+{Config.Awakening.mineralBonusPerAwakening}% minerals forever`)

	local ascension = data.ascension or { count = 0, points = 0, upgrades = {} }
	Ui.heading(
		list,
		nextOrder(),
		`Ascensions: {ascension.count} · Points: {ascension.points} · Unspent Awakenings: {data.awakening.count - (ascension.spentAwakenings or 0)}`
	)
	Ui.row(
		list,
		nextOrder(),
		`Requires {Config.Ascension.requiredAwakenings} unspent Awakenings and {Config.Bosses[Config.Ascension.requiredBoss].displayName}`,
		`Uses {Config.Ascension.requiredAwakenings} unspent Awakenings (keeps their bonuses). Resets level, parts, skills, minerals and bosses. Keeps artifacts, cosmetics, shards and all upgrades. Grants {Config.Ascension.points} point.`,
		if os.clock() < confirmAscendUntil then "Confirm Ascend" else "Ascend",
		Stats.canAscend(data),
		function()
			if os.clock() < confirmAscendUntil then
				confirmAscendUntil = 0
				State.request("ascend")
			else
				confirmAscendUntil = os.clock() + 4
				State.toast("Read the reset details, then tap Ascend again to confirm")
				Menus.refresh()
			end
		end
	)
	for _, id in Config.AscendUpgradeOrder do
		local upgrade = Config.AscendUpgrades[id]
		local rank = ascension.upgrades[id] or 0
		local bonuses = {}
		for stat, amount in upgrade.bonus do
			table.insert(bonuses, `+{amount}% {stat}`)
		end
		Ui.row(
			list,
			nextOrder(),
			`{upgrade.name} ({rank}/{upgrade.maxRank})`,
			table.concat(bonuses, ", ") .. " per rank",
			`{upgrade.cost} point`,
			rank < upgrade.maxRank and ascension.points >= upgrade.cost,
			function()
				State.request("buyAscendUpgrade", id)
			end
		)
	end

	Ui.heading(list, nextOrder(), "Shard upgrades")
	for _, id in Config.AwakenUpgradeOrder do
		local upgrade = Config.AwakenUpgrades[id]
		local rank = data.awakening.upgrades[id] or 0
		if rank >= upgrade.maxRank then
			Ui.row(list, nextOrder(), `{upgrade.name} (max rank)`, upgrade.description)
		else
			local cost = Stats.upgradeCost(id, rank)
			Ui.row(
				list,
				nextOrder(),
				`{upgrade.name} (rank {rank}/{upgrade.maxRank})`,
				`{upgrade.description} per rank`,
				`{cost} shards`,
				data.awakening.shards >= cost,
				function()
					State.request("buyUpgrade", id)
				end
			)
		end
	end
end

local function renderQuests(list: ScrollingFrame, snap: any)
	local rewards = snap.rewards
	if not rewards then
		return
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	Ui.heading(list, nextOrder(), "Daily login")
	local streakIndex = (rewards.daily.nextStreak - 1) % #Config.DailyRewards + 1
	Ui.row(
		list,
		nextOrder(),
		if rewards.daily.canClaim
			then `Day {rewards.daily.nextStreak} reward`
			else `Streak: {rewards.daily.streak} days`,
		if rewards.daily.canClaim
			then Ui.rewardText(Config.DailyRewards[streakIndex])
			else "Come back tomorrow for the next reward",
		"Claim",
		rewards.daily.canClaim,
		function()
			State.request("claimDaily")
		end
	)

	Ui.heading(list, nextOrder(), "Session gifts")
	local played = State.serverNow() - (snap.sessionStart or State.serverNow())
	for index, gift in Config.SessionRewards do
		local claimed = table.find(rewards.sessionClaimed, index) ~= nil
		local remaining = gift.minutes * 60 - played
		Ui.row(
			list,
			nextOrder(),
			`{gift.minutes} minute gift`,
			Ui.rewardText(gift),
			if claimed then "Opened" elseif remaining > 0 then Ui.duration(remaining) else "Open",
			not claimed and remaining <= 0,
			function()
				State.request("claimSession", index)
			end
		)
	end

	Ui.heading(list, nextOrder(), "Quests")
	for _, quest in rewards.quests do
		Ui.row(
			list,
			nextOrder(),
			(if quest.weekly then "Weekly: " else "") .. quest.text,
			`{quest.progress} / {quest.target}  ·  {Ui.rewardText(quest.reward)}`,
			if quest.claimed then "Claimed" else "Claim",
			not quest.claimed and quest.progress >= quest.target,
			function()
				State.request("claimQuest", quest.id)
			end
		)
	end

	if rewards.groupId ~= 0 and not rewards.groupClaimed then
		Ui.heading(list, nextOrder(), "Community")
		Ui.row(list, nextOrder(), "Join our Roblox group", Ui.rewardText(Config.Group.reward), "Check", true, function()
			State.request("claimGroup")
		end)
	end
end

local function renderParty(list: ScrollingFrame, snap: any)
	local party = snap.party
	if not party then
		return
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	Ui.heading(
		list,
		nextOrder(),
		`Party ({#party.members}/{Config.Party.maxSize})  ·  Friend bonus +{party.friendBonus}% minerals`
	)
	for _, member in party.members do
		local tags = {}
		if member.leader then
			table.insert(tags, "leader")
		end
		if member.friend then
			table.insert(tags, "friend")
		end
		Ui.row(list, nextOrder(), member.name, if #tags > 0 then table.concat(tags, ", ") else nil)
	end
	if party.inParty then
		Ui.row(list, nextOrder(), "Leave party", nil, "Leave", true, function()
			State.request("partyLeave")
		end)
	end

	if #party.invites > 0 then
		Ui.heading(list, nextOrder(), "Invites")
		for _, invite in party.invites do
			local frame = Ui.row(list, nextOrder(), `{invite.name} invited you`, nil, "Join", true, function()
				State.request("partyAccept", invite.userId)
			end)
			Ui.button(frame, "No", UDim2.new(0, 60, 1, -12), UDim2.new(1, -194, 0, 6), true, function()
				State.request("partyDecline", invite.userId)
			end)
		end
	end

	Ui.heading(list, nextOrder(), "Players in this server")
	if #party.others == 0 then
		Ui.row(list, nextOrder(), "Nobody else is here yet", "Invite a friend to play together!")
	end
	for _, other in party.others do
		Ui.row(
			list,
			nextOrder(),
			other.name,
			if other.inParty then "In a party" else nil,
			"Invite",
			not other.inParty,
			function()
				State.request("partyInvite", other.userId)
			end
		)
	end
	Ui.row(
		list,
		nextOrder(),
		"How parties work",
		"Members near a kill share its rewards. Each friend adds +10% minerals."
	)
end

-- The code being typed survives re-renders, and the list doesn't re-render
-- while the box has focus (that would drop the keyboard).
local codeDraft = ""
local codeBox: TextBox? = nil

local function renderShop(list: ScrollingFrame, snap: any)
	local data = snap.data
	local passes = snap.passes or {}
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	Ui.heading(list, nextOrder(), "Codes")
	local function redeem()
		if codeDraft ~= "" and State.request("redeemCode", codeDraft) then
			codeDraft = ""
		end
		Menus.refresh()
	end
	local codeRow = Ui.row(list, nextOrder(), "", nil, "Redeem", true, redeem)
	local box = Instance.new("TextBox")
	box.Name = "CodeBox"
	box.Size = UDim2.new(1, -150, 1, -12)
	box.Position = UDim2.fromOffset(6, 6)
	box.TextColor3 = Ui.Colors.text
	box.PlaceholderText = "Type a code"
	box.PlaceholderColor3 = Ui.Colors.quiet
	box.Text = codeDraft
	box.Font = Enum.Font.GothamBold
	box.TextScaled = true
	box.ClearTextOnFocus = false
	box.Parent = codeRow
	Ui.corner(box, 6)
	Ui.surface(box, "stone") -- a slot carved into the plate
	codeBox = box
	box:GetPropertyChangedSignal("Text"):Connect(function()
		codeDraft = string.sub(box.Text, 1, Config.CodeLimits.maxLength)
	end)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)
	Ui.row(list, nextOrder(), "Where to find codes", "New codes come out with updates and on our group wall.")

	Ui.row(
		list,
		nextOrder(),
		"Looking for skins and pets?",
		"Golem skins, wizard outfits, pets and trails are in the Wardrobe, with a preview."
	)

	Ui.heading(list, nextOrder(), "Game passes (forever)")
	for _, key in Config.GamePassOrder do
		local pass = Config.GamePasses[key]
		local owned = passes[key] == true
		Ui.row(
			list,
			nextOrder(),
			pass.name,
			pass.description,
			if owned then "Owned" elseif pass.id == 0 then "Coming soon" else `R$ {pass.price}`,
			not owned and pass.id ~= 0,
			function()
				Remotes.Track:FireServer("purchasePrompted", "pass", key)
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end
		)
	end

	Ui.heading(list, nextOrder(), "Packs and boosts")
	local now = State.serverNow()
	local policy = snap.policy or {}
	for _, key in Config.ProductOrder do
		local product = Config.Products[key]
		local activeFor = if product.boost then math.max((data.boosts[product.boost] or 0) - now, 0) else 0
		if product.paidRandom and not policy.paidRandomItems then
			-- Hidden where Roblox restricts paid random items, and until the
			-- server has checked. Time already bought still shows.
			if activeFor > 0 then
				Ui.row(list, nextOrder(), product.name, `Active for {Ui.duration(activeFor)}`)
			end
			continue
		end
		local subtitle = if product.boost then "Stacks with itself" else "Scales with your best island"
		if product.boost == "luck" then
			subtitle = `Doubles your artifact odds for {product.minutes} min. Your real odds are just below.`
		end
		if activeFor > 0 then
			subtitle = `Active for {Ui.duration(activeFor)}`
		end
		Ui.row(
			list,
			nextOrder(),
			product.name,
			subtitle,
			if product.id == 0 then "Coming soon" else `R$ {product.price}`,
			product.id ~= 0,
			function()
				Remotes.Track:FireServer("purchasePrompted", "product", key)
				MarketplaceService:PromptProductPurchase(player, product.id)
			end
		)
		if product.boost == "luck" then
			-- The player's actual odds on this island right now, from the same
			-- numbers the server rolls with, and what the boost changes them to.
			local zoneId = if snap.golem and Config.Zones[snap.golem.zoneId] then snap.golem.zoneId else 1
			local luckMult = Stats.compute(data, State.context()).luckMult
			local zoneName = Config.Zones[zoneId].name
			if activeFor > 0 then
				Ui.row(
					list,
					nextOrder(),
					`Your odds now on {zoneName} (2x Luck on)`,
					`{oddsText(data, zoneId, luckMult)}. Without it: {oddsText(data, zoneId, luckMult / 2)}.`
				)
			else
				Ui.row(
					list,
					nextOrder(),
					`Your odds now on {zoneName}`,
					`{oddsText(data, zoneId, luckMult)}. With 2x Luck: {oddsText(data, zoneId, luckMult * 2)}.`
				)
			end
			local pity = {}
			for _, source in { "drop", "boss" } do
				local _, rollsLeft, unfound = Stats.artifactOdds(data, zoneId, source, luckMult)
				local _, spareLeft, spares = Stats.spareOdds(data, zoneId, source, luckMult)
				local what = if source == "boss" then "boss defeats" else "enemies"
				if unfound > 0 then
					table.insert(pity, `{rollsLeft} more {what}`)
				elseif spares then
					table.insert(pity, `{spareLeft} more {what} for a spare copy`)
				end
			end
			if #pity > 0 then
				Ui.row(
					list,
					nextOrder(),
					"Bad-luck protection (boost or not)",
					`One is guaranteed here within {table.concat(pity, " or ")}.`
				)
			end
			Ui.row(list, nextOrder(), "Trading", "Spare copies found while 2x Luck is on can never be traded.")
		end
	end
	Ui.row(list, nextOrder(), "Fair play", "Everything that makes you stronger can also be earned by playing.")
end

local function renderWardrobe(list: ScrollingFrame, snap: any)
	local order = 0
	Wardrobe.render(list, snap, function(): number
		order += 1
		return order
	end, Menus.refresh)
end

local EARN_NAMES = { enemyDefeated = "enemy", nodeMined = "node", bossDefeated = "boss" }

local function renderEvents(list: ScrollingFrame, snap: any)
	local data = snap.data
	local now = State.serverNow()
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local shown = 0
	for _, event in Config.Events do
		local startsAt, endsAt = Stats.eventWindow(event, now)
		local live = startsAt ~= nil and endsAt ~= nil and now >= startsAt
		local state = data.eventTracks[event.id]
		if not startsAt and not state then
			continue -- a one-off event that's over and was never played
		end
		shown += 1
		Ui.heading(list, nextOrder(), event.name)
		local effects = Ui.modifierText(event.modifiers)
		if live and endsAt then
			Ui.row(
				list,
				nextOrder(),
				`Live now! Ends in {Ui.duration(endsAt - now)}`,
				if effects ~= "" then effects else event.description
			)
		elseif startsAt then
			Ui.row(list, nextOrder(), `Starts in {Ui.duration(startsAt - now)}`, event.description)
		else
			Ui.row(list, nextOrder(), "This event is over", "You can still claim rewards you earned.")
		end

		local track = event.track
		if track then
			local tokens = if state then state.tokens else 0
			local claimed = if state then state.claimed else {}
			-- Same rule as the server: a finished track starts over in a new run.
			if live and state and state.run ~= startsAt then
				local finished = true
				for index in track.tiers do
					if not claimed[tostring(index)] then
						finished = false
					end
				end
				if finished then
					tokens, claimed = 0, {}
				end
			end
			local earn = {}
			for eventName, amount in track.earn do
				table.insert(earn, `{amount} per {EARN_NAMES[eventName] or eventName}`)
			end
			table.sort(earn)
			Ui.row(
				list,
				nextOrder(),
				`{tokens} {track.currency}`,
				`Earn {table.concat(earn, ", ")} while the event is on.`
			)
			for index, tier in track.tiers do
				local done = claimed[tostring(index)] == true
				local ready = not done and tokens >= tier.tokens
				Ui.row(
					list,
					nextOrder(),
					`{tier.tokens} {track.currency}`,
					Ui.rewardText(tier.reward),
					if done
						then "Claimed"
						elseif ready then "Claim"
						else `{math.min(tokens, tier.tokens)} / {tier.tokens}`,
					ready,
					function()
						State.request("claimEventTier", event.id, index)
					end
				)
			end
		end
	end
	if shown == 0 then
		Ui.row(list, nextOrder(), "No events right now", "Check back after the next update!")
	end
	Ui.row(
		list,
		nextOrder(),
		"Fair play",
		"Event rewards are earned only by playing. Progress you don't finish carries over to the next run."
	)
end

local function renderRanks(list: ScrollingFrame, snap: any)
	local boards = snap.leaderboards or {}
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	for _, board in Config.Leaderboards.boards do
		Ui.heading(list, nextOrder(), board.displayName)
		local entries = boards[board.id]
		if not entries or #entries == 0 then
			Ui.row(
				list,
				nextOrder(),
				"No scores yet",
				"Leaderboards update every couple of minutes in published games."
			)
		else
			for rank, entry in entries do
				Ui.row(list, nextOrder(), `#{rank}  {entry.name}`, tostring(entry.value))
			end
		end
	end
end

---------------------------------------------------------------- hub

-- Whose inspect card is open in the Hub tab.
local inspectedId: number? = nil

local function unlockText(unlock: any): string
	if unlock.kind == "boss" then
		return `Defeat {Config.Bosses[unlock.zone].displayName}`
	elseif unlock.kind == "zoneSet" then
		return `Find every artifact in {Config.Zones[unlock.zone].name}`
	elseif unlock.kind == "awaken" then
		return `Awaken {unlock.count} time{if unlock.count == 1 then "" else "s"}`
	elseif unlock.kind == "level" then
		return `Reach level {unlock.level}`
	end
	return "Keep playing"
end

local function renderHub(list: ScrollingFrame, snap: any)
	local hub = snap.hub
	if not hub then
		return
	end
	local data = snap.data
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	Ui.heading(list, nextOrder(), `Players in this server ({#hub.others})`)
	if #hub.others == 0 then
		Ui.row(
			list,
			nextOrder(),
			"Nobody else is here yet",
			"Golems in the Golem Hub show off their parts. Open Travel to visit."
		)
	end
	for _, other in hub.others do
		local shown = inspectedId == other.userId
		local name = if other.title then `{other.name} · {other.title}` else other.name
		Ui.row(
			list,
			nextOrder(),
			name,
			`Level {other.level}  ·  Size {other.size}  ·  {other.awakenings} Awakenings`,
			if shown then "Hide" else "Inspect",
			true,
			function()
				inspectedId = if shown then nil else other.userId
				Menus.refresh()
			end
		)
		if shown then
			Ui.row(list, nextOrder(), "Golem parts", table.concat(other.parts, "  ·  "))
			Ui.row(
				list,
				nextOrder(),
				`Artifacts found {other.artifactsFound} / {#Config.ArtifactOrder}  ·  Zone bosses beaten {other.bosses} / {#Config.ZoneOrder}`,
				if #other.equipped > 0 then `Wearing: {table.concat(other.equipped, ", ")}` else "No artifacts equipped"
			)
		end
	end

	Ui.heading(list, nextOrder(), "Titles (shown on your nametag)")
	local wearing = Stats.equippedTitle(data)
	Ui.row(
		list,
		nextOrder(),
		"No title",
		if wearing == nil then "Wearing nothing" else nil,
		"Remove",
		wearing ~= nil,
		function()
			State.request("setTitle", "")
		end
	)
	for _, title in hub.titles do
		local def = Config.Titles[title.id]
		local on = wearing == title.name
		Ui.row(
			list,
			nextOrder(),
			title.name,
			if title.earned then "Earned" else unlockText(def.unlock),
			if on then "Wearing" elseif title.earned then "Wear" else "Locked",
			title.earned and not on,
			function()
				State.request("setTitle", title.id)
			end
		)
	end

	Ui.heading(list, nextOrder(), "Settings")
	local announce = data.social == nil or data.social.announce ~= false
	Ui.row(
		list,
		nextOrder(),
		`Rare-find announcements: {if announce then "On" else "Off"}`,
		"A short message when someone finds a boss or relic artifact.",
		if announce then "Turn off" else "Turn on",
		true,
		function()
			State.request("setAnnounce", not announce)
		end
	)
end

---------------------------------------------------------------- trade

local SOURCE_NAMES = { drop = "enemy drop", boss = "boss drop", hidden = "hidden relic" }

local function renderTrade(list: ScrollingFrame, snap: any)
	local trade = snap.trade
	if not trade then
		return
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local view = trade.trade

	if view then
		local name = view.partner.name
		Ui.heading(list, nextOrder(), `Trading with {name}`)

		Ui.heading(list, nextOrder(), "You give")
		for _, item in view.mine do
			Ui.row(list, nextOrder(), item.name, SOURCE_NAMES[item.source], "Remove", true, function()
				State.request("tradeRemove", item.id)
			end)
		end
		if #view.mine == 0 then
			Ui.row(list, nextOrder(), "Nothing yet", "Pick a spare copy below.")
		end
		local offered = {}
		for _, item in view.mine do
			offered[item.id] = true
		end
		for _, spare in trade.spares do
			if spare.tradable > 0 and not offered[spare.id] then
				Ui.row(
					list,
					nextOrder(),
					spare.name,
					`{spare.tradable} spare to trade`,
					"Offer",
					#view.mine < Config.Trading.maxItems,
					function()
						State.request("tradeOffer", spare.id)
					end
				)
			end
		end

		Ui.heading(list, nextOrder(), `You get from {name}`)
		for _, item in view.theirs do
			Ui.row(list, nextOrder(), item.name, SOURCE_NAMES[item.source])
		end
		if #view.theirs == 0 then
			Ui.row(
				list,
				nextOrder(),
				"Nothing yet",
				`{name} hasn't added anything. That's fine if it's a gift, but check.`
			)
		end

		if view.lopsided then
			Ui.row(
				list,
				nextOrder(),
				"Careful: you give much more than you get",
				"Only go ahead if you really want to. You can't undo a trade."
			)
		end
		Ui.row(
			list,
			nextOrder(),
			`You: {if view.myReady then "Ready" else "Not ready"}  ·  {name}: {if view.theirReady
				then "Ready"
				else "Not ready"}`,
			"Changing anything makes you both Ready again."
		)

		local bothReady = view.myReady and view.theirReady
		local remaining = if bothReady and view.confirmAt then view.confirmAt - State.serverNow() else 0
		if not bothReady then
			Ui.row(
				list,
				nextOrder(),
				if view.myReady then "Waiting for both of you to be Ready" else "Check the trade, then press Ready",
				nil,
				if view.myReady then "Not ready" else "Ready",
				view.myReady or #view.mine + #view.theirs > 0,
				function()
					State.request("tradeReady", not view.myReady)
				end
			)
		elseif remaining > 0 then
			Ui.row(
				list,
				nextOrder(),
				`Take a moment to check the trade ({remaining})`,
				"Confirm opens when the timer ends.",
				"Wait",
				false
			)
		elseif view.myConfirmed then
			Ui.row(list, nextOrder(), `Waiting for {name} to confirm`, nil, "Confirmed", false)
		else
			Ui.row(
				list,
				nextOrder(),
				"Both Ready. Confirm to swap.",
				if view.theirConfirmed then `{name} has confirmed.` else nil,
				if view.lopsided then "Confirm anyway" else "Confirm",
				true,
				function()
					State.request("tradeConfirm")
				end
			)
		end
		if bothReady and not view.myConfirmed then
			Ui.row(list, nextOrder(), "Not sure?", nil, "Not ready", true, function()
				State.request("tradeReady", false)
			end)
		end
		Ui.row(list, nextOrder(), "Cancel trade", nil, "Cancel", true, function()
			State.request("tradeCancel")
		end)
		Ui.row(
			list,
			nextOrder(),
			"Stay safe",
			"Only trade with people you know. Never trade because someone asked for Robux or something outside the game."
		)
		return
	end

	Ui.heading(list, nextOrder(), `Trade spare artifacts  ·  {trade.left} trades left today`)
	if trade.blocked then
		Ui.row(list, nextOrder(), "Trading is off for now", trade.blocked)
	end
	if #trade.incoming > 0 then
		Ui.heading(list, nextOrder(), "Requests")
		for _, request in trade.incoming do
			local frame = Ui.row(
				list,
				nextOrder(),
				`{request.name} wants to trade`,
				nil,
				"Accept",
				trade.blocked == nil,
				function()
					State.request("tradeAccept", request.userId)
				end
			)
			Ui.button(frame, "No", UDim2.new(0, 60, 1, -12), UDim2.new(1, -194, 0, 6), true, function()
				State.request("tradeDecline", request.userId)
			end)
		end
	end

	Ui.heading(list, nextOrder(), "Your spare copies")
	if #trade.spares == 0 then
		Ui.row(
			list,
			nextOrder(),
			"No spares yet",
			"Find every artifact from a source on an island, and the same drops give spare copies."
		)
	end
	for _, spare in trade.spares do
		Ui.row(
			list,
			nextOrder(),
			spare.name,
			`{spare.tradable} to trade`
				.. (if spare.bound > 0 then `  ·  {spare.bound} bound (found with 2x Luck)` else "")
		)
	end

	Ui.heading(list, nextOrder(), "Friends and party members here")
	if #trade.partners == 0 then
		Ui.row(
			list,
			nextOrder(),
			"Nobody to trade with yet",
			"You can trade with Roblox friends and party members. Invite someone from Party."
		)
	end
	for _, partner in trade.partners do
		Ui.row(
			list,
			nextOrder(),
			partner.name,
			if partner.busy then "Busy trading" else nil,
			"Trade",
			trade.blocked == nil and not partner.busy,
			function()
				State.request("tradeRequest", partner.userId)
			end
		)
	end
	Ui.row(
		list,
		nextOrder(),
		"How trading works",
		"Only spare artifact copies. Both of you press Ready, wait for the timer, then both Confirm."
	)
end

local TABS: { { id: string, name: string, render: Render } } = {
	{ id = "forge", name = "Forge", render = renderForge },
	{ id = "travel", name = "Travel", render = renderTravel },
	{ id = "artifacts", name = "Artifacts", render = renderArtifacts },
	{ id = "skills", name = "Skills", render = renderSkills },
	{ id = "awaken", name = "Awaken", render = renderAwaken },
	{ id = "quests", name = "Quests", render = renderQuests },
	{ id = "events", name = "Events", render = renderEvents },
	{ id = "party", name = "Party", render = renderParty },
	{ id = "hub", name = "Hub", render = renderHub },
	{ id = "trade", name = "Trade", render = renderTrade },
	{ id = "wardrobe", name = "Wardrobe", render = renderWardrobe },
	{ id = "shop", name = "Shop", render = renderShop },
	{ id = "ranks", name = "Ranks", render = renderRanks },
}

---------------------------------------------------------------- window

local window: Frame
local titleLabel: TextLabel
local list: ScrollingFrame
local openTab: number? = nil
local tabButtons: { [string]: TextButton } = {}

-- The tutorial points at these.
function Menus.getTabButton(id: string): TextButton?
	return tabButtons[id]
end

function Menus.isOpen(id: string): boolean
	return openTab ~= nil and TABS[openTab].id == id
end

function Menus.refresh()
	if not openTab or not State.snapshot then
		return
	end
	if codeBox and codeBox.Parent and codeBox:IsFocused() then
		return
	end
	codeBox = nil
	Wardrobe.detach()
	local scroll = list.CanvasPosition
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local tab = TABS[openTab]
	titleLabel.Text = tab.name
	local ok, err = pcall(function(): any
		tab.render(list, State.snapshot)
		return nil
	end)
	if not ok then
		warn(`[Menus] {tab.name} failed to render: {err}`)
	end
	list.CanvasPosition = scroll
end

local function indexOf(id: string): number?
	for index, tab in TABS do
		if tab.id == id then
			return index
		end
	end
	return nil
end

local open: (index: number?) -> ()

local function showInspect(userId: number)
	inspectedId = userId
	local index = indexOf("hub")
	if openTab ~= index then
		open(index)
	else
		Menus.refresh()
	end
end

function open(index: number?)
	openTab = if openTab == index then nil else index
	window.Visible = openTab ~= nil
	if openTab and TABS[openTab].id == "shop" then
		Remotes.Track:FireServer("shopOpened") -- the Shop funnel in analytics
	end
	Menus.refresh()
end

function Menus.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GolemMenus"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Tab buttons down the left edge, under the stats panel.
	-- Scrolls, so every tab stays reachable on a short screen.
	local bar = Instance.new("ScrollingFrame")
	bar.Name = "Tabs"
	bar.BackgroundTransparency = 1
	bar.BorderSizePixel = 0
	bar.ScrollBarThickness = 0
	bar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	bar.CanvasSize = UDim2.new()
	bar.Size = UDim2.new(0, 110, 1, -220)
	bar.Position = UDim2.fromOffset(12, 180)
	bar.Parent = gui
	local barLayout = Instance.new("UIListLayout")
	barLayout.Padding = UDim.new(0, 6)
	barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	barLayout.Parent = bar
	for index, tab in TABS do
		local b = Ui.button(bar, tab.name, UDim2.fromOffset(110, 34), UDim2.new(), true, function()
			open(index)
		end)
		b.LayoutOrder = index
		tabButtons[tab.id] = b
		b.BackgroundTransparency = 0.05
		Ui.surface(b, "studs", { details = true })
	end

	window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.52)
	window.Size = UDim2.fromScale(0.5, 0.66)
	window.BackgroundTransparency = 0.05
	window.Visible = false
	window.Parent = gui
	Ui.corner(window, 12)
	Ui.surface(window, "wood", { details = true })
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 260)
	constraint.MaxSize = Vector2.new(640, 620)
	constraint.Parent = window

	titleLabel = Ui.label(window, "", UDim2.new(1, -70, 0, 30), UDim2.fromOffset(16, 10))
	local close = Ui.button(window, "X", UDim2.fromOffset(36, 36), UDim2.new(1, -46, 0, 8), true, function()
		open(openTab)
	end)
	Ui.surface(close, "metal")

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Size = UDim2.new(1, -20, 1, -60)
	list.Position = UDim2.fromOffset(10, 50)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	State.Changed:Connect(Menus.refresh)
	-- Pressing Inspect on a golem in the hub opens its card.
	Remotes.Notify.OnClientEvent:Connect(function(kind: string, userId: number?)
		if kind == "inspect" and type(userId) == "number" then
			showInspect(userId)
		end
	end)
	-- Timers (session gifts, boosts) tick even without new state.
	task.spawn(function()
		while true do
			task.wait(1)
			if
				openTab
				and (
					TABS[openTab].id == "quests"
					or TABS[openTab].id == "shop"
					or TABS[openTab].id == "artifacts"
					or TABS[openTab].id == "trade"
					or TABS[openTab].id == "awaken"
					or TABS[openTab].id == "events"
				)
			then
				Menus.refresh()
			end
		end
	end)
end

return Menus
