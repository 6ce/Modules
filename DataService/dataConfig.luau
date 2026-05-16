local repStorage = game:GetService("ReplicatedStorage")

local t = require(repStorage.Shared.Libraries.Typechecker)

local TEMPLATE = {
	
}

--[[
	Data validators
]]
local SCHEMA = t.strictInterface({
	
})

local MIGRATIONS = {
	Fields = {
		
	};
	
	Transforms = {
		
	};
}

export type PlayerData = typeof(TEMPLATE)
export type ProfileKey = keyof<PlayerData>

return {
	ProductionDataVersion = 1;
	StudioDataVersion = 1;
	IsStudioDataSeparated = false;
	
	DataStoreFormat = "PlayerData%s";
	Schema = SCHEMA;
	Template = TEMPLATE;
	Migrations = MIGRATIONS;
}
