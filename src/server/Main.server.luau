--!strict
-- Server entry point. Services live in the Services folder next to this script
-- and are added one build slice at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)

local count = Loader.boot(script.Parent:FindFirstChild("Services"))
print(`[StockTycoon] Server started with {count} service(s)`)
