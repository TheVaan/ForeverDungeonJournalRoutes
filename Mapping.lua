-- Maps a Dungeon Journal (FDJ) map page to a Forever Dungeon Routes (FDR) dungeon key and floor.
--
-- Both addons draw the same map art with the same normalised 0..1 coordinates (origin top-left),
-- so no coordinate conversion is needed, only the floor identification:
--   * FDJ floors with a uiMapID use the client's own map; FDR uses that uiMapID as its floor id.
--   * FDJ floors with only a custom picture (the new Forever dungeons, Zul'Farrak, Sunken Temple)
--     are listed below by FDJ dungeon name, one FDR floor id per FDJ floor, in FDJ floor order.
local _, NS = ...
local Mapping = {}
NS.Mapping = Mapping

-- [FDJ dungeon name] = { [FDJ floor index] = FDR floor id (false: FDR has no floor for it) }
local FIXED = {
	["Hall of Thanes"]            = { 1030651 },
	["Ruins of Lordaeron"]        = { 1029991 },
	-- FDJ lists the Underbelly first, FDR lists the city first.
	["City of Dalaran"]           = { 1029592, 1029591 },
	-- Atal'Byzal (floor 2) has no FDR counterpart.
	["The Drowned City"]          = { 1029701, false },
	["Blackmaw Hold"]             = { 1029741, 1029742, 1029743, 1029744, 1029745, 1029746 },
	["Krol'dok Stronghold"]       = { 1030391 },
	["Alcaz Prison"]              = { 1029941, 1029942 },
	["Shaper's Terrace"]          = { 1030011 },
	["Excavation Site: Wetlands"] = { 1029981 },
	["Zul'Farrak"]                = { 219 },
	["Sunken Temple"]             = { 220 },
}

local nameByData

-- FDJ keeps the selected dungeon in a file local, so find the dungeon name from its map data table.
function Mapping.DungeonName(FDJ, data)
	if not (FDJ and FDJ.DUNGEON_MAPS and data) then return nil end
	if not nameByData or nameByData[data] == nil then
		nameByData = {}
		for name, mapData in pairs(FDJ.DUNGEON_MAPS) do nameByData[mapData] = name end
	end
	return nameByData[data]
end

-- Returns the FDR dungeon key and FDR floor id for FDJ floor `floorIndex` of `data`, or nil.
function Mapping.Resolve(FDJ, FDR, data, floorIndex)
	local floors = data and data.floors
	local floorData = floors and floors[floorIndex]
	if not floorData then return nil end
	local fdrFloor = floorData.uiMapID
	if not fdrFloor then
		local list = FIXED[Mapping.DungeonName(FDJ, data) or ""]
		fdrFloor = list and list[floorIndex]
	end
	if not fdrFloor then return nil end
	local key = FDR:GetKeyForFloor(fdrFloor)
	if not key then return nil end
	return key, fdrFloor
end

-- The FDJ floor index that shows FDR floor `fdrFloor`, or nil when FDJ has no such floor.
function Mapping.FloorIndex(FDJ, FDR, data, fdrFloor)
	local floors = data and data.floors
	if not floors or not fdrFloor then return nil end
	for i = 1, #floors do
		local _, floor = Mapping.Resolve(FDJ, FDR, data, i)
		if floor == fdrFloor then return i end
	end
	return nil
end
