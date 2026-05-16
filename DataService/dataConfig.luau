local repStorage = game:GetService("ReplicatedStorage")

local t = require(repStorage.Shared.Libraries.Typechecker)

-- default data template for each player
local TEMPLATE = {
	
}

-- each key in the template will be validated
-- against this schema 
local SCHEMA = t.strictInterface({
	
})

-- in order to add values or transform them
-- you must add it here
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
