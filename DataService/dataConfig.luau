local repStorage = game:GetService("ReplicatedStorage")

local t = require(repStorage.Shared.Libraries.Typechecker)

-- default data template for each player
local TEMPLATE = {
	
}

type DataTransformerFn = (data: PlayerData) -> PlayerData
export type PlayerData = typeof(TEMPLATE)
export type ProfileKey = keyof<PlayerData>

type MigrationData = {
	Fields: { [string]: { [string]: any } };
	Transforms: { [string]: DataTransformerFn }
}


-- each key in the template will be validated
-- against this schema 
local SCHEMA = t.strictInterface({
	
})

-- in order to add values or transform them
-- you must add it here
local MIGRATIONS: MigrationData = {
	Fields = {
		
	};
	
	Transforms = {
		
	};
}

return {
	ProductionDataVersion = 1;
	StudioDataVersion = 1;
	IsStudioDataSeparated = false;
	DataStoreFormat = "PlayerData%s";
	
	Schema = SCHEMA;
	Template = TEMPLATE;
	Migrations = MIGRATIONS;
}
