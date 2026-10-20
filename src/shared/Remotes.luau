--!strict
-- Every RemoteEvent the game uses. The server creates them in
-- ReplicatedStorage.Remotes; the client waits for them. Anything a client sends
-- must be rate-limited on the server before it is acted on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local function findOrCreate(parent: Instance, name: string, className: string): Instance
	if not IS_SERVER then
		return parent:WaitForChild(name)
	end

	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local folder = findOrCreate(ReplicatedStorage, "Remotes", "Folder")

local function event(name: string): RemoteEvent
	return findOrCreate(folder, name, "RemoteEvent") :: RemoteEvent
end

return {
	-- Server to client: a short message shown to that player on screen.
	Notify = event("Notify"),

	-- Client to server: (itemId: string) buy a company off a conveyor.
	BuyConveyorItem = event("BuyConveyorItem"),

	-- Client to server: (plotKey: string) place the carried company on a plot.
	PlaceOnPlot = event("PlaceOnPlot"),

	-- Client to server: (plotKey: string) pick up the company on a plot.
	PickUpFromPlot = event("PickUpFromPlot"),

	-- Client to server: () put the carried company into storage.
	StoreCarried = event("StoreCarried"),

	-- Client to server: (instanceId: string) take a company out of storage.
	TakeFromStorage = event("TakeFromStorage"),

	-- Client to server: () buy the next base upgrade.
	BuyUpgrade = event("BuyUpgrade"),
}
