--!strict
-- Shows short messages from the server to this player, such as a reply to an
-- admin command, as notification toasts near the top of the screen (Ui/Kit/
-- Toasts). The server may name a kind (Info, Success, Warning or Error) after
-- the message to colour its edge; without one it's Info.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Toasts = require(script.Parent.Parent.Ui.Kit.Toasts)

local KINDS = { Info = true, Success = true, Warning = true, Error = true }

local NotifyController = {}

function NotifyController:Start()
	Remotes.Notify.OnClientEvent:Connect(function(message: unknown, kind: unknown)
		if typeof(message) ~= "string" then
			return
		end
		local valid: Toasts.Kind? = if typeof(kind) == "string" and KINDS[kind] then kind :: any else nil
		Toasts.show(message, valid)
	end)
end

return NotifyController
