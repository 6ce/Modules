-- https://paradoxum-games.github.io/lyra/

local repStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService('RunService')
local players = game:GetService("Players")

local t = require(repStorage.Shared.Libraries.Typechecker)
local signal = require(repStorage.Shared.Classes.Signal)
local observe = require(repStorage.Shared.Libraries.Observe)

local lyra = require(script.Parent.Parent.Modules.Lyra)

local isInStudio = runService:IsStudio()

local dataConfig = require(script.DataConfig)

local storeKey = dataConfig.DataStoreFormat:format(
	(isInStudio and dataConfig.StudioDataVersion) or dataConfig.ProductionDataVersion
)

if isInStudio and dataConfig.IsStudioDataSeparated then
	storeKey ..= "_Studio"
end

local onPlayerLoadedSignal = signal.new()
local onPlayerUnloadedSignal = signal.new()

local assertIsPlayer = t.instanceIsA("Player")

local beforePlayerUnloadFns: { [string]: BeforePlayerUnloadFn } = {}
local beforeGameCloseFns: { [string]: EmptyCallbackFn } = {}
local dataChangedFns: { PlayerDataChangedFn } = {}

local successfullyLoadedPlayers: { [Player]: boolean? } = {}

local PLAYER_UNLOAD_FN_TIMEOUT = 5
local GAME_CLOSE_FN_TIMEOUT = 10

local migrationSteps = {} do
	for idx, fn in dataConfig.Migrations.Transforms do
		table.insert(migrationSteps, lyra.MigrationStep.transform(idx, fn))
	end
	
	for idx, fields in dataConfig.Migrations.Fields do
		table.insert(migrationSteps, lyra.MigrationStep.addFields(idx, fields))
	end
end

local module = {
	Store = lyra.createPlayerStore({
		name = storeKey;
		template = dataConfig.Template;
		schema = dataConfig.Schema;
		migrationSteps = migrationSteps;
		changedCallbacks = {
			function(key, newData, oldData)
				local player = players:GetPlayerByUserId(tonumber(key))
				if not player then return end
				
				for _, callback in dataChangedFns do
					task.spawn(callback, player, newData, oldData)
				end
			end
		};
	});
	
	Configuration = dataConfig;
}

export type DataService = typeof(module)

type UpdatePlayerDataFn = (data: dataConfig.PlayerData) -> boolean
type PlayerTransactionFn = (state: { [Player]: dataConfig.PlayerData }) -> ()
type PlayerDataChangedFn = (player: Player, newData: dataConfig.PlayerData, oldData: dataConfig.PlayerData) -> ()
type OnPlayerLoadedFn = (player: Player, data: dataConfig.PlayerData) -> ()
type OnPlayerUnloadedFn = (player: Player) -> ()
type BeforePlayerUnloadFn = (player: Player, data: dataConfig.PlayerData) -> ()
type EmptyCallbackFn = () -> ()

local function insertCallback<V>(
	tbl: {V},
	callback: V,
	idx: any?
): EmptyCallbackFn
	if idx ~= nil then
		tbl[idx] = callback
	else
		table.insert(tbl, callback)
	end
	
	return function()
		if idx ~= nil then
			tbl[idx] = nil
		else
			table.remove(tbl, table.find(tbl, callback))
		end
	end
end

local function ensureCallbackWithTimeout<V...>(
	callbackType: string,
	callbackName: string,
	timeout: number,
	fn: (V...) -> (),
	...: V...
)
	local startTime = os.clock()
	local isFinished = false

	local thread = task.spawn(function(...)
		local args = table.concat({ ... }, ", ")
		
		xpcall(fn, function(err)
			local tb = debug.traceback(err, 2)
			warn(`Callback of type '{callbackType}' of name '{callbackName}' failed with arguments : {tb}`)
		end, ...)
		
		isFinished = true
	end, ...)

	while not isFinished do
		local elapsed = os.clock() - startTime

		if elapsed > timeout then
			pcall(task.cancel, thread)
			warn(`Callback of type '{callbackType}' of name '{callbackName}' timed out ({string.format("%.2f", elapsed)}s)`)
			break
		end

		task.wait(0.1)
	end
end

local function onPlayerRemoving(
	self: DataService,
	player: Player
)
	if successfullyLoadedPlayers[player] == nil then
		return
	end

	successfullyLoadedPlayers[player] = nil

	local data = self:getAsync(player)

	for idx, fn in beforePlayerUnloadFns do
		ensureCallbackWithTimeout(
			"Player unload", idx, PLAYER_UNLOAD_FN_TIMEOUT, fn, 
			player, data
		)
	end

	self.Store:unload(player):andThen(function()
		onPlayerUnloadedSignal:Fire(player)
	end):catch(function(err)
		warn(`[{storeKey}] Failed to unload player data for '{player.Name}': {err}`)
	end)
end

local function onPlayerAdded(
	self: DataService,
	player: Player
)
	local startTime = os.clock()
	
	self.Store:load(player):andThen(function()
		successfullyLoadedPlayers[player] = true
		
		if not player:IsDescendantOf(game) then
			warn(`[{storeKey}] Player data finished loading after player left`)
			onPlayerRemoving(self, player)
			return
		end
		
		local elapsed = string.format("%.2f", os.clock() - startTime)
		local data = self:getAsync(player)

		onPlayerLoadedSignal:Fire(player, data)
		
		if runService:IsStudio() then
			print(`[{storeKey}] Loaded player data for '{player.Name}' in {elapsed}s:`, data)
		else
			print(`[{storeKey}] Loaded player data for '{player.Name}' in {elapsed}s`)
		end
	end):catch(function(err)
		local elapsed = string.format("%.2f", os.clock() - startTime)
		warn(`[{storeKey}] Failed to load player data for '{player.Name}' in {elapsed}s: {err}`)
	end)
end

local function onGameClosing(
	self: DataService
)
	local startTime = os.clock()
	
	for idx, fn in beforeGameCloseFns do
		ensureCallbackWithTimeout("Game closing", idx, GAME_CLOSE_FN_TIMEOUT, fn)
	end
	
	local success, err = self.Store:close():await()
	
	if success then
		local elapsed = os.clock() - startTime
		print(`[{storeKey}] Player data stored closed successfully in {string.format("%.2f", elapsed)}s`)
	else
		warn(`[{storeKey}] Failed to close player data store: {err}`)
	end
end

--[[
	Returns a promise which can be used to access the input player's data
]]
function module.get(
	self: DataService,
	player: Player
)
	assert(assertIsPlayer(player))
	
	return self.Store:get(player)
end

--[[
	Returns a promise which can be used to access the input userId's saved data
]]
function module.peek(
	self: DataService,
	userId: number
)
	assert(t.number(userId))
	
	return self.Store:peek(userId)
end

--[[
	Yields and returns the input userId's saved data
]]
function module.peekAsync(
	self: DataService,
	userId: number
)
	assert(t.number(userId))
	
	return self.Store:peekAsync(userId)
end

--[[
	Yields and returns the input player's current data
]]
function module.getAsync(
	self: DataService,
	player: Player
)
	assert(assertIsPlayer(player))
	
	return self.Store:getAsync(player)
end

--[[
	Calls the input callback with the player's data, allowing updates to be made
	directly to the data table
	
	The callback should return a boolean, whether it should commit the changes or not
	
	Returns a promise which can be used to see the status of the update
]]
function module.update(
	self: DataService,
	player: Player,
	transform: UpdatePlayerDataFn
)
	return self.Store:update(player, transform)
end

--[[
	Calls the input callback with a table which contains the input players as the keys
	and their data as the values
	
	If any of the players' data is not loaded when this is called, the promise will be
	rejected with an error
	
	The callback should return a boolean, whether it should commit the changes or not
	
	Returns a promise which can be used to see the status of the transaction
]]
function module.transaction(
	self: DataService,
	playerList: {Player},
	transform: PlayerTransactionFn
)
	return self.Store:tx(playerList, transform)
end

--[[
	Calls the input callback whenever a player's data is changed
	Returns a function which can be used to disconnect the callback
]]
function module.onPlayerDataChanged(
	self: DataService,
	callback: PlayerDataChangedFn
): EmptyCallbackFn
	assert(t.callback(callback))
	
	return insertCallback(dataChangedFns, callback)
end

--[[
	Calls the input callback whenever a player's data is first loaded
	Returns a Connection object which can be used to disconnect the callback
]]
function module.onPlayerLoaded(
	self: DataService,
	callback: OnPlayerLoadedFn
): signal.Connection
	assert(t.callback(callback))
	
	return onPlayerLoadedSignal:Connect(callback)
end

--[[
	Calls the input callback whenever a player's data is unloaded
	Note that if a player leaves before their data is loaded, this will never be called
	Returns a Connection object which can be used to disconnect the callback
]]
function module.onPlayerUnloaded(
	self: DataService,
	callback: OnPlayerUnloadedFn
): signal.Connection
	assert(t.callback(callback))
	
	return onPlayerUnloadedSignal:Connect(callback)
end

--[[
	Calls the input callback before the game's datastore closes (when game:BindToClose is called)
	The input callback has a timeout of 10 seconds before it automatically continues with a warning
]]
function module.beforeDatastoreCloses(
	self: DataService,
	name: string,
	callback: EmptyCallbackFn
): EmptyCallbackFn
	assert(t.string(name))
	assert(t.callback(callback))
	
	return insertCallback(beforeGameCloseFns, callback, name)
end

--[[
	Calls the input callback before a player's data unloads and saves (on PlayerRemoving)
	The input callback has a timeout of 5 seconds before it automatically continues with a warning
]]
function module.beforePlayerDataUnloads(
	self: DataService,
	name: string,
	callback: BeforePlayerUnloadFn
): EmptyCallbackFn
	assert(t.string(name))
	assert(t.callback(callback))
	
	return insertCallback(beforePlayerUnloadFns, callback, name)
end

function module.init(
	self: DataService
)
	observe.player(function(...)
		onPlayerAdded(self, ...)
	end)
	
	players.PlayerRemoving:Connect(function(...)
		onPlayerRemoving(self, ...)
	end)
	
	game:BindToClose(function(...)
		onGameClosing(self, ...)
	end)
end

return module
