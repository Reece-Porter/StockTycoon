--!strict
-- Shows messages from the server to this player as system lines in chat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local NotifyController = {}

function NotifyController:Start()
	local systemChannel = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXSystem") :: TextChannel

	Remotes.Notify.OnClientEvent:Connect(function(message: string)
		systemChannel:DisplaySystemMessage(message)
	end)
end

return NotifyController
