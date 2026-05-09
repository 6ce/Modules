local module = {}

local collectionService = game:GetService("CollectionService")
local players = game:GetService("Players")

--[[
	Observes when an instance with a tag is added
]]
function module.tag<V>(
	tag: string,
	callback: (instance: V) -> ()
): RBXScriptConnection
	local connection = collectionService:GetInstanceAddedSignal(tag):Connect(callback)
	
	for _, obj in collectionService:GetTagged(tag) do
		task.spawn(callback, obj)
	end
	
	return connection
end

--[[
	Observes when an instance's property is changed
]]
function module.property<T, V>(
	instance: T & Instance,
	property: keyof<T>,
	callback: (value: V) -> (),
	default: V?
): RBXScriptConnection
	local connection = instance:GetPropertyChangedSignal(property):Connect(function()
		callback(instance[property])
	end)
	
	local initialValue = instance[property]
	
	if initialValue == nil then
		initialValue = default
	end
	
	if initialValue ~= nil then
		task.spawn(callback, initialValue)
	end
	
	return connection
end

--[[
	Observes when an instance's attribute is changed
]]
function module.attribute<V>(
	instance: Instance,
	attribute: string,
	callback: (value: V) -> (),
	default: V?
): RBXScriptConnection
	local connection = instance:GetAttributeChangedSignal(attribute):Connect(function()
		callback(instance:GetAttribute(attribute) or default)
	end)
	
	local value = instance:GetAttribute(attribute)
	
	if value == nil then
		value = default
	end
	
	if value ~= nil then
		task.spawn(callback, value)
	end
	
	return connection
end

--[[
	Observes a player's character
]]
function module.character(
	player: Player,
	callback: (character: Model) -> ()
): RBXScriptConnection
	local conn = player.CharacterAdded:Connect(callback)
	
	if player.Character then
		task.spawn(callback, player.Character)
	end
	
	return conn
end

--[[
	Observes when a player is added
]]
function module.player(
	callback: (player: Player) -> ()
): RBXScriptConnection
	local conn = players.PlayerAdded:Connect(callback)
	
	for _, player in players:GetPlayers() do
		task.spawn(callback, player)
	end
	
	return conn
end

--[[
	Observes when a child of an instance is added
]]
function module.child(
	parent: Instance,
	callback: (child: Instance) -> ()
): RBXScriptConnection
	local conn = parent.ChildAdded:Connect(callback)
	
	for _, child in parent:GetChildren() do
		task.spawn(callback, child)
	end
	
	return conn
end

--[[
	Observes when a descendant of an instance is added
]]
function module.descendant(
	parent: Instance,
	callback: (descendant: Instance) -> ()
): RBXScriptConnection
	local conn = parent.DescendantAdded:Connect(callback)

	for _, child in parent:GetDescendants() do
		task.spawn(callback, child)
	end

	return conn
end

return module
