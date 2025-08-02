--[[
	@RBA - A module dedicated to wrapping TextChatCommand logic
]]

local module = {}

local players = game:GetService("Players")

type OnCommandRanCallback = (player: Player, args: {string}) -> (boolean, string)
type OnCommandErroredCallback = (
	command: TextChatCommand, 
	player: Player, 
	message: string, 
	args: {string},
	errMessage: string
) -> ()

local onCommandErroredEvent = Instance.new("BindableEvent")

local function getArgsFromCommand(
	command: TextChatCommand,
	message: string
): {string}
	local args = string.split(message, " ")
	
	-- remove command from args
	table.remove(args, 1)
	
	return args
end

--[[
	Sets up the input TextChatCommand with the input callback
	
	The callback should return if running the command was a success
	and if not, it should return an error message which is shown to the player
	
	If no error message is returned, the no error message will be shown
]]
function module:onCommandRan(
	command: TextChatCommand,
	callback: OnCommandRanCallback
): RBXScriptConnection
	return command.Triggered:Connect(function(source, text)
		local player = players:GetPlayerByUserId(source.UserId)
		
		if player then
			local args = getArgsFromCommand(command, text)
			local success, errMessage = callback(player, args)
			
			if not success and errMessage and player:IsDescendantOf(game) then				
				onCommandErroredEvent:Fire(command, player, text, args, errMessage)
			end
		end
	end)
end

function module:onCommandErrored(
	callback: OnCommandErroredCallback
): RBXScriptConnection
	return onCommandErroredEvent.Event:Connect(callback)
end

return module
