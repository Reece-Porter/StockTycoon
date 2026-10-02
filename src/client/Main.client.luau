--!strict
-- Client entry point. Controllers and UI live in the Controllers folder next to
-- this script and are added one build slice at a time.

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)

local count = Loader.boot(script.Parent:FindFirstChild("Controllers"))
print(`[StockTycoon] Client started with {count} controller(s)`)
