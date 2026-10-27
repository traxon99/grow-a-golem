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

local Menus = {}

local player = Players.LocalPlayer

type Render = (list: ScrollingFrame, snap: any) -> ()

local function tierRank(tier: string?): number
	return if tier then (table.find(Config.TierOrder, tier) or 0) else 0
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
	Ui.row(list, nextOrder(), `Health {stats.maxHealth}  ·  Damage {math.floor(stats.attackDamage)}`,
		`Mining {math.floor(stats.miningDamage)}  ·  Speed {math.floor(stats.walkSpeed)}`
			.. (if stats.fullSet then `  ·  Full {Config.Tiers[stats.fullSet].displayName} set bonus!` else ""))

	Ui.heading(list, nextOrder(), "Forge parts")
	for _, slot in Config.SlotOrder do
		local current = data.golem.parts[slot]
		local currentName = if current then Config.Tiers[current].displayName else "Bare stone"
		local nextTier = Config.TierOrder[tierRank(current) + 1]
		if nextTier then
			local cost = Stats.partCost(slot, nextTier)
			Ui.row(list, nextOrder(), `{Config.Slots[slot].displayName}: {currentName}`,
				`Next: {Config.Tiers[nextTier].displayName} for {Ui.costText(cost)}`,
				"Forge", Stats.canAfford(data, cost), function()
					State.request("craftPart", slot, nextTier)
				end)
		else
			Ui.row(list, nextOrder(), `{Config.Slots[slot].displayName}: {currentName}`, "Best tier forged")
		end
	end
	Ui.row(list, nextOrder(), "Tip", "Forge all five parts from the same tier for +15% health and damage.")
end

local function renderTravel(list: ScrollingFrame, snap: any)
	local data = snap.data
	local currentZone = if snap.golem then snap.golem.zoneId else 1
	Ui.heading(list, 1, "Islands")
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
		Ui.row(list, index + 1, zone.name, subtitle, "Travel", unlocked and zoneId ~= currentZone, function()
			State.request("travel", zoneId)
		end)
	end
end

local function renderArtifacts(list: ScrollingFrame, snap: any)
	local data = snap.data
	local stats = Stats.compute(data, State.context())
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	Ui.heading(list, nextOrder(), `Equipped {#data.artifacts.equipped} / {stats.artifactSlots}  ·  Found {Stats.artifactsFound(data)} / {#Config.ArtifactOrder}`)

	local sourceHint = { drop = "Rare drop from enemies", boss = "Dropped by the zone boss", hidden = "A glowing relic hidden on the island" }
	for _, zoneId in Config.ZoneOrder do
		local complete = Stats.zoneSetComplete(data, zoneId)
		local found, total = Stats.zoneArtifactCount(data, zoneId)
		Ui.heading(list, nextOrder(), `{Config.Zones[zoneId].name}  {found} / {total}` .. (if complete then `  (set complete: {Ui.bonusText(Config.ZoneSetBonus)})` else `  ·  complete it for {Ui.bonusText(Config.ZoneSetBonus)}`))
		-- The real odds, including luck, and how close bad-luck protection is.
		for _, source in { "drop", "boss" } do
			local chance, rollsLeft, unfound = Stats.artifactOdds(data, zoneId, source, stats.luckMult)
			if unfound > 0 then
				local who = if source == "boss" then "boss defeat" else "enemy defeated"
				Ui.row(list, nextOrder(), `Odds: {string.format("%.2f", chance * 100)}% per {who}`,
					`{unfound} left to find. One is guaranteed within {rollsLeft} more.`)
			end
		end
		for _, id in Config.ArtifactOrder do
			local artifact = Config.Artifacts[id]
			if artifact.zone == zoneId then
				if data.artifacts.found[id] then
					local equipped = table.find(data.artifacts.equipped, id) ~= nil
					Ui.row(list, nextOrder(), artifact.name, Ui.bonusText(artifact.bonus),
						if equipped then "Unequip" else "Equip", true, function()
							State.request(if equipped then "unequipArtifact" else "equipArtifact", id)
						end)
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
	Ui.row(list, nextOrder(), `Skill points: {Stats.skillPointsAvailable(data)}`, "You earn 1 point per level.",
		"Reset", next(data.skills) ~= nil, function()
			State.request("respecSkills")
		end)
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
			Ui.row(list, nextOrder(), `{skill.name} ({skill.cost} pt)`, table.concat(extra, ", "),
				if learned then "Learned" else "Learn", canLearn and not learned, function()
					State.request("learnSkill", skillId)
				end)
		end
	end
end

local confirmAwakenUntil = 0
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
	Ui.row(list, nextOrder(),
		if canAwaken then `Awaken now for {Stats.awakeningShards(level)} shards` else `Reach level {Config.Awakening.minLevel} to Awaken`,
		"Resets level, parts, skills, minerals, and bosses. Keeps artifacts, shards, and upgrades.",
		if confirming then "Tap to confirm" else "Awaken", canAwaken, function()
			if os.clock() < confirmAwakenUntil then
				confirmAwakenUntil = 0
				State.request("awaken")
			else
				confirmAwakenUntil = os.clock() + 4
				State.toast("Tap Awaken again to confirm")
				Menus.refresh()
			end
		end)
	Ui.row(list, nextOrder(), "Every Awakening", `+{Config.Awakening.mineralBonusPerAwakening}% minerals forever`)

	Ui.heading(list, nextOrder(), "Shard upgrades")
	for _, id in Config.AwakenUpgradeOrder do
		local upgrade = Config.AwakenUpgrades[id]
		local rank = data.awakening.upgrades[id] or 0
		if rank >= upgrade.maxRank then
			Ui.row(list, nextOrder(), `{upgrade.name} (max rank)`, upgrade.description)
		else
			local cost = Stats.upgradeCost(id, rank)
			Ui.row(list, nextOrder(), `{upgrade.name} (rank {rank}/{upgrade.maxRank})`, `{upgrade.description} per rank`,
				`{cost} shards`, data.awakening.shards >= cost, function()
					State.request("buyUpgrade", id)
				end)
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
	Ui.row(list, nextOrder(),
		if rewards.daily.canClaim then `Day {rewards.daily.nextStreak} reward` else `Streak: {rewards.daily.streak} days`,
		if rewards.daily.canClaim then Ui.rewardText(Config.DailyRewards[streakIndex]) else "Come back tomorrow for the next reward",
		"Claim", rewards.daily.canClaim, function()
			State.request("claimDaily")
		end)

	Ui.heading(list, nextOrder(), "Session gifts")
	local played = State.serverNow() - (snap.sessionStart or State.serverNow())
	for index, gift in Config.SessionRewards do
		local claimed = table.find(rewards.sessionClaimed, index) ~= nil
		local remaining = gift.minutes * 60 - played
		Ui.row(list, nextOrder(), `{gift.minutes} minute gift`, Ui.rewardText(gift),
			if claimed then "Opened" elseif remaining > 0 then Ui.duration(remaining) else "Open",
			not claimed and remaining <= 0, function()
				State.request("claimSession", index)
			end)
	end

	Ui.heading(list, nextOrder(), "Quests")
	for _, quest in rewards.quests do
		Ui.row(list, nextOrder(), (if quest.weekly then "Weekly: " else "") .. quest.text,
			`{quest.progress} / {quest.target}  ·  {Ui.rewardText(quest.reward)}`,
			if quest.claimed then "Claimed" else "Claim", not quest.claimed and quest.progress >= quest.target, function()
				State.request("claimQuest", quest.id)
			end)
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
	Ui.heading(list, nextOrder(), `Party ({#party.members}/{Config.Party.maxSize})  ·  Friend bonus +{party.friendBonus}% minerals`)
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
		Ui.row(list, nextOrder(), other.name, if other.inParty then "In a party" else nil, "Invite", not other.inParty, function()
			State.request("partyInvite", other.userId)
		end)
	end
	Ui.row(list, nextOrder(), "How parties work", "Members near a kill share its rewards. Each friend adds +10% minerals.")
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
	box.BackgroundColor3 = Ui.Colors.panel
	box.TextColor3 = Ui.Colors.text
	box.PlaceholderText = "Type a code"
	box.PlaceholderColor3 = Ui.Colors.quiet
	box.Text = codeDraft
	box.Font = Enum.Font.GothamBold
	box.TextScaled = true
	box.ClearTextOnFocus = false
	box.Parent = codeRow
	Ui.corner(box, 6)
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

	Ui.heading(list, nextOrder(), "Game passes (forever)")
	for _, key in Config.GamePassOrder do
		local pass = Config.GamePasses[key]
		local owned = passes[key] == true
		Ui.row(list, nextOrder(), pass.name, pass.description,
			if owned then "Owned" elseif pass.id == 0 then "Coming soon" else `R$ {pass.price}`,
			not owned and pass.id ~= 0, function()
				Remotes.Track:FireServer("purchasePrompted", "pass", key)
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end)
	end

	Ui.heading(list, nextOrder(), "Packs and boosts")
	local now = State.serverNow()
	for _, key in Config.ProductOrder do
		local product = Config.Products[key]
		local subtitle = if product.boost then "Stacks with itself" else "Scales with your best island"
		if product.boost == "luck" then
			subtitle = `Doubles artifact odds: {string.format("%.2f", Config.ArtifactDropChance * 100)}% to {string.format("%.2f", Config.ArtifactDropChance * 200)}% per enemy, {math.floor(Config.ArtifactBossChance * 100)}% to {math.floor(math.min(Config.ArtifactBossChance * 200, 100))}% per boss`
		end
		if product.boost and (data.boosts[product.boost] or 0) > now then
			subtitle = `Active for {Ui.duration(data.boosts[product.boost] - now)}`
		end
		Ui.row(list, nextOrder(), product.name, subtitle,
			if product.id == 0 then "Coming soon" else `R$ {product.price}`, product.id ~= 0, function()
				Remotes.Track:FireServer("purchasePrompted", "product", key)
				MarketplaceService:PromptProductPurchase(player, product.id)
			end)
	end
	Ui.row(list, nextOrder(), "Fair play", "Everything that makes you stronger can also be earned by playing.")
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
			Ui.row(list, nextOrder(), `Live now! Ends in {Ui.duration(endsAt - now)}`, if effects ~= "" then effects else event.description)
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
			Ui.row(list, nextOrder(), `{tokens} {track.currency}`,
				`Earn {table.concat(earn, ", ")} while the event is on.`)
			for index, tier in track.tiers do
				local done = claimed[tostring(index)] == true
				local ready = not done and tokens >= tier.tokens
				Ui.row(list, nextOrder(), `{tier.tokens} {track.currency}`, Ui.rewardText(tier.reward),
					if done then "Claimed" elseif ready then "Claim" else `{math.min(tokens, tier.tokens)} / {tier.tokens}`,
					ready, function()
						State.request("claimEventTier", event.id, index)
					end)
			end
		end
	end
	if shown == 0 then
		Ui.row(list, nextOrder(), "No events right now", "Check back after the next update!")
	end
	Ui.row(list, nextOrder(), "Fair play", "Event rewards are earned only by playing. Progress you don't finish carries over to the next run.")
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
			Ui.row(list, nextOrder(), "No scores yet", "Leaderboards update every couple of minutes in published games.")
		else
			for rank, entry in entries do
				Ui.row(list, nextOrder(), `#{rank}  {entry.name}`, tostring(entry.value))
			end
		end
	end
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
	local scroll = list.CanvasPosition
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local tab = TABS[openTab]
	titleLabel.Text = tab.name
	local ok, err = pcall(tab.render, list, State.snapshot)
	if not ok then
		warn(`[Menus] {tab.name} failed to render: {err}`)
	end
	list.CanvasPosition = scroll
end

local function open(index: number?)
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
	local bar = Instance.new("Frame")
	bar.Name = "Tabs"
	bar.BackgroundTransparency = 1
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
		b.BackgroundColor3 = Ui.Colors.panel
		b.BackgroundTransparency = 0.15
	end

	window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.52)
	window.Size = UDim2.fromScale(0.5, 0.66)
	window.BackgroundColor3 = Ui.Colors.panel
	window.BackgroundTransparency = 0.05
	window.Visible = false
	window.Parent = gui
	Ui.corner(window, 12)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 260)
	constraint.MaxSize = Vector2.new(640, 620)
	constraint.Parent = window

	titleLabel = Ui.label(window, "", UDim2.new(1, -70, 0, 30), UDim2.fromOffset(16, 10))
	Ui.button(window, "X", UDim2.fromOffset(36, 36), UDim2.new(1, -46, 0, 8), true, function()
		open(openTab)
	end)

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
	-- Timers (session gifts, boosts) tick even without new state.
	task.spawn(function()
		while true do
			task.wait(1)
			if openTab and (TABS[openTab].id == "quests" or TABS[openTab].id == "shop" or TABS[openTab].id == "awaken" or TABS[openTab].id == "events") then
				Menus.refresh()
			end
		end
	end)
end

return Menus
