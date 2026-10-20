--!strict
-- A gold [VIP] tag in front of the names of players with the VIP game pass,
-- in the chat. The server marks them with the PassVIP attribute
-- (MonetisationService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Monetisation = require(ReplicatedStorage.Shared.Config.Monetisation)

local ChatTagsController = {}

function ChatTagsController:Start()
	local colour = Monetisation.VipColour:ToHex()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
		local source = message.TextSource
		local speaker = if source then Players:GetPlayerByUserId(source.UserId) else nil
		if speaker == nil or speaker:GetAttribute("PassVIP") ~= true then
			return nil
		end
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = `<font color="#{colour}">[VIP]</font> {message.PrefixText}`
		return properties
	end
end

return ChatTagsController
