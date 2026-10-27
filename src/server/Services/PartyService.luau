--!strict
-- Co-op parties of up to Config.Party.maxSize players. Party members near a
-- kill share its rewards, and every friend in your party adds a mineral bonus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)

type Party = { leader: Player, members: { Player } }

local PartyService = {}

local partyOf: { [Player]: Party } = {}
local invites: { [Player]: { [Player]: number } } = {} -- target -> inviter -> expiry (os.clock)
local friendCache: { [Player]: { [number]: boolean } } = {}

local function refreshAll(party: Party?)
	if party then
		for _, member in party.members do
			DataService.markChanged(member)
		end
	end
end

local function isFriend(a: Player, b: Player): boolean
	local cache = friendCache[a]
	if not cache then
		cache = {}
		friendCache[a] = cache
	end
	if cache[b.UserId] == nil then
		local ok, result = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		cache[b.UserId] = ok and result == true
	end
	return cache[b.UserId]
end

-- Whether two players are Roblox friends (looked up once, then remembered).
function PartyService.areFriends(a: Player, b: Player): boolean
	return isFriend(a, b)
end

-- Like areFriends but never waits: unknown pairs read as "not friends" until
-- the lookup finishes in the background, then the player's state refreshes.
-- For snapshots, which must not stall.
function PartyService.friendNow(a: Player, b: Player): boolean
	local cache = friendCache[a]
	if cache and cache[b.UserId] ~= nil then
		return cache[b.UserId]
	end
	if not a.Parent then
		return false
	end
	task.spawn(function()
		isFriend(a, b)
		DataService.markChanged(a)
	end)
	return false
end

function PartyService.sameParty(a: Player, b: Player): boolean
	return partyOf[a] ~= nil and partyOf[a] == partyOf[b]
end

function PartyService.members(player: Player): { Player }
	local party = partyOf[player]
	return if party then party.members else { player }
end

-- % mineral bonus from friends in the same party.
function PartyService.friendBonus(player: Player): number
	local bonus = 0
	for _, member in PartyService.members(player) do
		if member ~= player and isFriend(player, member) then
			bonus += Config.Party.friendBonusPerFriend
		end
	end
	return math.min(bonus, Config.Party.maxFriendBonus)
end

-- Players who share a reward earned by `player` at `position`.
-- `isNear(member)` lets the caller decide what "near" means (same zone, in range).
function PartyService.shareWith(player: Player, isNear: (Player) -> boolean): { Player }
	local result = { player }
	for _, member in PartyService.members(player) do
		if member ~= player and isNear(member) then
			table.insert(result, member)
		end
	end
	return result
end

local function leave(player: Player)
	local party = partyOf[player]
	if not party then
		return
	end
	partyOf[player] = nil
	local index = table.find(party.members, player)
	if index then
		table.remove(party.members, index)
	end
	if #party.members <= 1 then
		for _, member in party.members do
			partyOf[member] = nil
		end
	elseif party.leader == player then
		party.leader = party.members[1]
	end
	refreshAll(party)
	DataService.markChanged(player)
	for _, member in party.members do
		Remotes.Notify:FireClient(member, "message", `{player.DisplayName} left the party.`)
	end
end

local function snapshot(player: Player): any
	local party = partyOf[player]
	local members = {}
	for _, member in PartyService.members(player) do
		table.insert(members, {
			userId = member.UserId,
			name = member.DisplayName,
			leader = party ~= nil and party.leader == member,
			friend = member ~= player and isFriend(player, member),
		})
	end
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(others, { userId = other.UserId, name = other.DisplayName, inParty = partyOf[other] ~= nil })
		end
	end
	local pending = {}
	local now = os.clock()
	for inviter, expiry in invites[player] or {} do
		if expiry > now and inviter.Parent then
			table.insert(pending, { userId = inviter.UserId, name = inviter.DisplayName })
		end
	end
	return {
		members = members,
		inParty = party ~= nil,
		friendBonus = PartyService.friendBonus(player),
		others = others,
		invites = pending,
	}
end

function PartyService.start()
	DataService.addProvider("party", snapshot)

	ActionService.register("partyInvite", function(player, userId)
		if type(userId) ~= "number" then
			return false, "Pick a player"
		end
		local target = Players:GetPlayerByUserId(userId)
		if not target or target == player then
			return false, "That player isn't here"
		end
		if partyOf[target] then
			return false, `{target.DisplayName} is already in a party`
		end
		if #PartyService.members(player) >= Config.Party.maxSize then
			return false, "Your party is full"
		end
		invites[target] = invites[target] or {}
		invites[target][player] = os.clock() + Config.Party.inviteTimeout
		Remotes.Notify:FireClient(
			target,
			"message",
			`{player.DisplayName} invited you to a party! Open Party to accept.`
		)
		DataService.markChanged(target)
		return true, `Invite sent to {target.DisplayName}`
	end)

	ActionService.register("partyAccept", function(player, userId)
		local inviter = type(userId) == "number" and Players:GetPlayerByUserId(userId)
		local pending = invites[player]
		if not inviter or not pending or (pending[inviter] or 0) < os.clock() then
			return false, "That invite expired"
		end
		pending[inviter] = nil
		if partyOf[player] then
			leave(player)
		end
		local party = partyOf[inviter]
		if not party then
			party = { leader = inviter, members = { inviter } }
			partyOf[inviter] = party
		end
		if #party.members >= Config.Party.maxSize then
			return false, "That party is full"
		end
		table.insert(party.members, player)
		partyOf[player] = party
		refreshAll(party)
		for _, member in party.members do
			Remotes.Notify:FireClient(member, "message", `{player.DisplayName} joined the party!`)
		end
		Events.fire("partyJoined", player, #party.members)
		return true, nil
	end)

	ActionService.register("partyDecline", function(player, userId)
		local inviter = type(userId) == "number" and Players:GetPlayerByUserId(userId)
		if inviter and invites[player] then
			invites[player][inviter] = nil
		end
		DataService.markChanged(player)
		return true, nil
	end)

	ActionService.register("partyLeave", function(player)
		leave(player)
		return true, "You left the party"
	end)

	Players.PlayerAdded:Connect(function()
		-- Refresh everyone's invite list.
		for _, other in Players:GetPlayers() do
			DataService.markChanged(other)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		invites[player] = nil
		friendCache[player] = nil
		for _, pending in invites do
			pending[player] = nil
		end
		for _, other in Players:GetPlayers() do
			if other ~= player then
				DataService.markChanged(other)
			end
		end
	end)
end

return PartyService
