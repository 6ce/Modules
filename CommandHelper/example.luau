local textChatService = game:GetService("TextChatService")
local serverStorage = game:GetService("ServerStorage")

local commandHelper = require(game.ServerStorage.CommandHelper)

local giveCashCommand = textChatService.Commands.GiveCashCommand

local function onGiveCashErrored(
	cmd: TextChatCommand, 
	player: Player, 
	msg: string, 
	args: {string}, 
	err: string
)
	if cmd == giveCashCommand then
		warn(`Failed to run give cash command: {err}`)
	end
end

local function onGiveCashRan(
	player: Player,
	args: {string}
): (boolean, string?)
	if not isPlayerWhitelisted(player) then
		return false, "You cannot run this command"
	end
	
	local amt = tonumber(args[1])
	
	if amt then
		module:giveCash(player, amt)
		return true
	end
	
	return false, "You did not give a valid cash amount"
end

commandHelper:onCommandRan(giveCashCommand, onGiveCashRan)
commandHelper:onCommandErrored(onGiveCashErrored)
