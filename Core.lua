-- Routes for DungeonJournal: shows the routes of Forever Dungeon Routes (FDR) on the Dungeon Journal (FDJ) maps.
--
-- FDJ has no plugin interface, so this hooks FDJ.RenderCustomDungeonMap (every map render goes through it)
-- and draws on the journal's map art holder afterwards. Everything is wrapped so that an error here can
-- never break the journal's own map; if FDJ changes and the pieces are missing, the addon stays off.
local _, NS = ...
_G.ForeverDungeonJournalRoutes = NS

local DE = GetLocale() == "deDE"
local strings = {
	route = { "Route", "Route" },
	toggletip = { "Left-click: show or hide the dungeon route.", "Linksklick: Dungeon-Route ein- oder ausblenden." },
	menutip = { "Choose the route and what is shown.", "Route und Anzeige wählen." },
	stops = { "Boss numbers and stops", "Boss-Nummern und Stopps" },
	notes = { "Notes", "Notizen" },
	gotolevel = { "Click: go to this level.", "Klick: zu dieser Ebene wechseln." },
	shown = { "Route shown.", "Route eingeblendet." },
	hidden = { "Route hidden.", "Route ausgeblendet." },
	missing = { "ForeverDungeonJournal and ForeverDungeonRoutes must be enabled.",
		"ForeverDungeonJournal und ForeverDungeonRoutes müssen aktiviert sein." },
	incompatible = { "Unsupported Dungeon Journal version; routes are disabled.",
		"Nicht unterstützte Dungeon-Journal-Version; Routen sind deaktiviert." },
	ready = { "Ready. /fdjr shows or hides the route on the journal maps.",
		"Bereit. /fdjr blendet die Route auf den Journal-Karten ein oder aus." },
}
function NS.T(key)
	local s = strings[key]
	return s and s[DE and 2 or 1] or key
end
function NS.Print(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cffe6b85cRoutes for DungeonJournal|r:" .. tostring(text))
end

local FDJ, FDR, db
local last              -- { data = FDJ map data } of the last map render
local lastKey           -- FDR dungeon key of what is shown now (nil: no route here)
local controls

local function Safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then geterrorhandler()(err) end
end

-- Controls (bottom right of the map panel, in the dark strip beside the art) -----------------

local Refresh

local function Redraw()
	if last and last.data then Safe(Refresh, last.data) end
end

local function SelectRoute(key, route)
	FDR:SetActiveRoute(key, route.id) -- fires ROUTE_CHANGED, which redraws
	local jf = _G.ForeverDungeonJournalFrame
	local start = FDR:GetRouteStartFloor(route)
	local index = start and last and NS.Mapping.FloorIndex(FDJ, FDR, last.data, start)
	if index and jf and index ~= jf.dungeonMapFloor then
		if FDJ.ResetDungeonMapView then FDJ.ResetDungeonMapView() end
		FDJ.RenderCustomDungeonMap(last.data, index)
	end
end

local function OpenMenu(owner)
	local key = lastKey
	if not key then return end
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, root)
			root:CreateTitle(FDR:GetKeyName(key))
			for _, route in ipairs(FDR:GetRoutes(key)) do
				local chosen = route
				root:CreateRadio(FDR:GetRouteName(route), function()
					local active = FDR:GetActiveRoute(key)
					return active ~= nil and active.id == chosen.id
				end, function() SelectRoute(key, chosen) end)
			end
			if root.CreateDivider then root:CreateDivider() end
			root:CreateCheckbox(NS.T("stops"), function() return db.stops end,
				function() db.stops = not db.stops Redraw() end)
			root:CreateCheckbox(NS.T("notes"), function() return db.notes end,
				function() db.notes = not db.notes Redraw() end)
		end)
	else
		-- No menu API: step through the routes.
		local routes, active = FDR:GetRoutes(key), FDR:GetActiveRoute(key)
		for i, route in ipairs(routes) do
			if active and route.id == active.id then
				SelectRoute(key, routes[i % #routes + 1])
				return
			end
		end
		if routes[1] then SelectRoute(key, routes[1]) end
	end
end

local function Tip(button, text)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(text, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function EnsureControls(panel)
	if controls then return controls end
	local c = CreateFrame("Frame", nil, panel)
	c:SetSize(102, 22)
	c:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
	local function Button(width)
		local b = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
		b:SetSize(width, 22)
		if FDJ.OwnFonts then pcall(FDJ.OwnFonts, b) end
		return b
	end
	c.toggle = Button(76)
	c.toggle:SetPoint("LEFT", 0, 0)
	c.toggle:SetScript("OnClick", function() db.show = not db.show Redraw() end)
	Tip(c.toggle, NS.T("toggletip"))
	c.menu = Button(22)
	c.menu:SetPoint("LEFT", c.toggle, "RIGHT", 4, 0)
	c.menu:SetText("v")
	c.menu:SetScript("OnClick", function(self) Safe(OpenMenu, self) end)
	Tip(c.menu, NS.T("menutip"))
	controls = c
	return c
end

local function UpdateControls(panel, holder, key)
	if not key then
		if controls then controls:Hide() end
		return
	end
	local c = EnsureControls(panel)
	c:SetFrameLevel(holder:GetFrameLevel() + 30)
	c.toggle:SetText((db.show and "|cff66ff88" or "|cffaaaaaa") .. NS.T("route") .. "|r")
	c:Show()
end

-- Drawing ----------------------------------------------------------------------------------

Refresh = function(data)
	local jf = _G.ForeverDungeonJournalFrame
	local holder = jf and jf.dungeonMapArtHolder
	local panel = jf and jf.dungeonMapPanel
	if not (holder and panel and data) then return end
	last = { data = data }
	local floorIndex = jf.dungeonMapFloor or 1
	local key, fdrFloor = NS.Mapping.Resolve(FDJ, FDR, data, floorIndex)
	local route = key and FDR:GetActiveRoute(key)
	lastKey = route and key or nil
	UpdateControls(panel, holder, lastKey)
	if not (route and db.show) then
		NS.Render.Clear()
		return
	end
	local _, holderHeight = holder:GetSize()
	NS.Render.Draw({
		FDJ = FDJ, FDR = FDR, db = db, holder = holder, data = data, floorIndex = floorIndex,
		dungeonName = NS.Mapping.DungeonName(FDJ, data), baseH = jf.dungeonMapBaseH or holderHeight or 368,
		key = key, route = route, fdrFloor = fdrFloor,
	})
end

-- Start-up ---------------------------------------------------------------------------------

local function Start()
	FDJ, FDR = _G.ForeverDungeonJournal_NS, _G.ForeverDungeonRoutes
	if not (FDJ and FDR and FDR.db) then NS.Print(NS.T("missing")) return end
	if not (type(FDJ.RenderCustomDungeonMap) == "function" and type(FDJ.DUNGEON_MAPS) == "table"
		and FDR.GetActiveRoute and FDR.GetKeyForFloor and FDR.GetStopLabels and FDR.On and FDR.GradientColor) then
		NS.Print(NS.T("incompatible"))
		return
	end
	ForeverDungeonJournalRoutesDB = ForeverDungeonJournalRoutesDB or {}
	db = ForeverDungeonJournalRoutesDB
	NS.db = db
	if db.show == nil then db.show = true end
	if db.stops == nil then db.stops = true end
	if db.notes == nil then db.notes = true end

	hooksecurefunc(FDJ, "RenderCustomDungeonMap", function(data) Safe(Refresh, data) end)
	for _, event in ipairs({ "ROUTE_CHANGED", "PROGRESS_CHANGED", "ROUTE_LIST_CHANGED", "EDITOR_CHANGED" }) do
		FDR:On(event, Redraw)
	end
	NS.Print(NS.T("ready"))
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	Safe(Start)
end)

SLASH_FOREVERDUNGEONJOURNALROUTES1 = "/fdjr"
SlashCmdList.FOREVERDUNGEONJOURNALROUTES = function(input)
	if not db then NS.Print(NS.T("missing")) return end
	input = strtrim(input or ""):lower()
	if input == "on" then db.show = true
	elseif input == "off" then db.show = false
	else db.show = not db.show end
	NS.Print(db.show and NS.T("shown") or NS.T("hidden"))
	Redraw()
end
