--!strict
-- Personal sanctuary plots and the first restoration, the hearth (#218).
--
-- A player who has discovered the sanctuary gets one runtime plot on the
-- Sanctuary Approach while they're in the server; the restoration itself
-- lives in their save (campaign.projects), so any plot shows it after a
-- rejoin. When every plot is taken, newcomers wait in a queue and are given
-- the next one that frees up; no plot is ever handed to two players.
--
-- Restoring the hearth spends the disclosed stone/copper and marks it done
-- in one save mutation, only for the plot's owner standing their golem by
-- it. Visitors see the owner's hearth (plot attributes replicate) but can't
-- act on it. A restored hearth unlocks a free Return Home trip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local KingdomRules = require(Shared:WaitForChild("KingdomRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)
local Plots = require(script.Parent.Parent.Models.Kingdom)

local SanctuaryService = {}

local FLAT = Vector3.new(1, 0, 1)

local owners: { [number]: Player? } = {} -- plot index -> player
local plotOf: { [Player]: number } = {}
local queue: { Player } = {}
local hearths: { [number]: Instance } = {} -- plot index -> the plot's model, for its attributes

local function show(index: number)
	local model = hearths[index]
	if not model then
		return
	end
	local owner = owners[index]
	local data = if owner then DataService.get(owner) else nil
	local restored = data ~= nil and data.campaign.projects.hearth == true
	model:SetAttribute("OwnerId", if owner then owner.UserId else 0)
	model:SetAttribute("OwnerName", if owner then owner.DisplayName else "")
	model:SetAttribute("Restored", restored)
	Plots.showHearth(model, restored, if owner then owner.DisplayName else nil)
end

function SanctuaryService.plotOf(player: Player): number?
	return plotOf[player]
end

function SanctuaryService.queued(player: Player): boolean
	return table.find(queue, player) ~= nil
end

-- Gives the player a plot if they've found the sanctuary and don't have one.
function SanctuaryService.assign(player: Player): number?
	if plotOf[player] then
		return plotOf[player]
	end
	local data = DataService.get(player)
	if not data or data.campaign.discoveries.sanctuary ~= true then
		return nil
	end
	for index = 1, #Config.Kingdom.sanctuary.plots do
		if owners[index] == nil then
			owners[index] = player
			plotOf[player] = index
			local waiting = table.find(queue, player)
			if waiting then
				table.remove(queue, waiting)
			end
			show(index)
			return index
		end
	end
	if not table.find(queue, player) then
		table.insert(queue, player)
		Remotes.Notify:FireClient(player, "message", Config.Kingdom.sanctuary.fullText)
	end
	return nil
end

-- Frees a leaving player's plot (their saved work stays) and hands it on.
function SanctuaryService.release(player: Player)
	local waiting = table.find(queue, player)
	if waiting then
		table.remove(queue, waiting)
	end
	local index = plotOf[player]
	if not index then
		return
	end
	plotOf[player] = nil
	owners[index] = nil
	show(index)
	while #queue > 0 and owners[index] == nil do
		local nextPlayer = table.remove(queue, 1) :: Player
		SanctuaryService.assign(nextPlayer)
	end
end

local function hearthPosition(index: number): Vector3
	return Config.Kingdom.sanctuary.plots[index]
end

local function restoreHearth(player: Player): (boolean, string?)
	if not Config.Kingdom.enabled then
		return false, "Not available yet."
	end
	local data = DataService.get(player)
	local index = plotOf[player]
	if not data or not index then
		return false, "Find your sanctuary plot first."
	end
	if data.campaign.projects.hearth == true then
		return false, "Your hearth is already burning."
	end
	local golem = GolemService.get(player)
	if not golem or not GolemService.isActive(golem) or golem.zoneId ~= 1 then
		return false, "Bring your golem to your hearth."
	end
	local config = Config.Kingdom.sanctuary.hearth
	local reach = config.reachRadius + Config.Golem.dismountOffset * golem.stats.scale
	if ((golem.root.Position - hearthPosition(index)) * FLAT).Magnitude > reach then
		return false, "Bring your golem to your hearth."
	end
	local cost = config.cost
	if not Stats.canAfford(data, cost) then
		return false, `Need {Stats.costText(cost)}.`
	end
	-- Spend and complete together: no yield between the check and the change.
	DataService.update(player, function(d)
		for mineral, amount in cost do
			d.minerals[mineral] -= amount
		end
		d.campaign.projects.hearth = true
	end)
	Events.fire("mineralsSpent", player, cost, "hearth")
	Events.fire("projectCompleted", player, "hearth")
	show(index)
	return true, "The hearth is lit! Return Home is open in Travel."
end

local function returnHome(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not Config.Kingdom.enabled or not data or data.campaign.projects.hearth ~= true then
		return false, "Restore your hearth first."
	end
	if not KingdomRules.pieceOpen(data, "quarryWall") then
		return false, "Open the quarry road first."
	end
	local golem = GolemService.get(player)
	if not golem or not GolemService.isActive(golem) then
		return false, "Wait for your golem to rebuild."
	end
	local index = plotOf[player] or SanctuaryService.assign(player)
	local base = if index then hearthPosition(index) else Config.Kingdom.sanctuary.plots[1]
	GolemService.travelTo(golem, 1, base + Config.Kingdom.sanctuary.returnOffset)
	DataService.markChanged(player)
	return true, "Welcome home!"
end

function SanctuaryService.start()
	if not Config.Kingdom.enabled then
		return
	end
	local models = Plots.buildPlots(Config.Kingdom.sanctuary)
	for index, model in models do
		hearths[index] = model
		show(index)
	end
	ActionService.register("restoreHearth", restoreHearth)
	ActionService.register("returnHome", returnHome)
	Events.connect("discovered", function(player, id)
		if id == "sanctuary" then
			SanctuaryService.assign(player)
		end
	end)
	DataService.ProfileLoaded:Connect(function(player)
		SanctuaryService.assign(player)
	end)
	Players.PlayerRemoving:Connect(SanctuaryService.release)
end

SanctuaryService.restoreHearth = restoreHearth
SanctuaryService.returnHome = returnHome

return SanctuaryService
