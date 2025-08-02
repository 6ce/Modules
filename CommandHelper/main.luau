--[[
	@RBA - A module dedicated to wrapping TextChatCommand logic
	
	onCommandRan Example:
	
		local giveCashCommand: TextChatCommand = textChatService.GiveCashCommand
		
		CommandHandler:onCommandRan(giveCashCommand, function(player, args)
			if not isPlayerWhitelisted(player) then
				return false, "You cannot run this command"
			end
			
			local amt = tonumber(args[1])
			
			if amt then
				module:giveCash(player, amt)
				return true
			end
			
			return false, "You did not give a valid cash amount"
		end)
		
	onCommandErrored Example:
	
		CommandHandler:onCommandErrored(function(cmd, player, msg, args, err)
			warn(`{player.Name} failed to run command '{msg}': {err}`)
		end)
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

--[[
	Calls the input callback whenever a command callback errors
]]
function module:onCommandErrored(
	callback: OnCommandErroredCallback
): RBXScriptConnection
	return onCommandErroredEvent.Event:Connect(callback)
end

return module
