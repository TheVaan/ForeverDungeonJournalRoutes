-- Draws a Forever Dungeons Routes route onto the Dungeon Journal map (paths, numbered stops, notes, level links).
--
-- Everything lives in one overlay frame that is a child of the journal's map art holder
-- (ForeverDungeonJournalFrame.dungeonMapArtHolder). The holder is exactly the map art, so a route
-- coordinate (0..1, origin top-left, y down) lands at (x * width, -y * height) from its top-left.
-- The holder moves with pan and is resized (and re-rendered by the journal) on zoom, and it clips its
-- children, so the overlay needs no extra handling for either.
local _, NS = ...
local Render = {}
NS.Render = Render

local MEDIA = "Interface\\AddOns\\ForeverDungeonRoutes\\media\\"
local sqrt, floor, max, min = math.sqrt, math.floor, math.max, math.min

local LINE_CASING, LINE_MAIN, LINE_SIDE = 5, 3, 2   -- pixel thickness
local MIN_SEGMENT = 2                                -- merge route points closer than this (pixels)
local ARROW_FIRST, ARROW_STEP = 30, 48               -- pixel spacing of the direction arrows
local DASH, GAP = 6, 4                               -- dashed side paths

local RING = {
	boss = { 0.95, 0.76, 0.31 }, rare = { 0.89, 0.87, 0.82 }, optional = { 0.62, 0.78, 0.95 },
	note = { 0.90, 0.38, 0.30 }, link = { 0.40, 0.70, 1.00 },
}
local TEXT = {
	boss = { 1.00, 0.91, 0.66 }, rare = { 0.89, 0.87, 0.82 }, optional = { 0.80, 0.89, 1.00 },
	note = { 1.00, 0.80, 0.75 }, link = { 0.80, 0.90, 1.00 },
}

local layer                -- overlay frame, child of the map art holder
local pools = {}           -- [draw sublevel] = { used = n, items = { Line, ... } }
local pins, usedPins = {}, 0
local width, height = 0, 0
local current              -- context of the last Draw (for clicks on level links)
local fontFace = GameFontHighlightSmall and (GameFontHighlightSmall:GetFont()) or "Fonts\\FRIZQT__.TTF"

local function EnsureLayer(holder)
	if not layer then
		layer = CreateFrame("Frame", nil, holder)
	elseif layer:GetParent() ~= holder then
		layer:SetParent(holder)
	end
	layer:ClearAllPoints()
	layer:SetAllPoints(holder)
	-- Above the map art, below the journal's boss pins (+10) and its controls (+30).
	layer:SetFrameLevel(holder:GetFrameLevel() + 9)
	return layer
end

-- Lines ------------------------------------------------------------------------------------

local function Line(sub, x1, y1, x2, y2, thickness, red, green, blue, alpha)
	local pool = pools[sub]
	if not pool then pool = { used = 0, items = {} } pools[sub] = pool end
	pool.used = pool.used + 1
	local line = pool.items[pool.used]
	if not line then
		line = layer:CreateLine(nil, "ARTWORK", nil, sub)
		pool.items[pool.used] = line
	end
	line:SetThickness(thickness)
	line:SetColorTexture(red, green, blue, alpha or 1)
	line:SetStartPoint("TOPLEFT", layer, x1, -y1)
	line:SetEndPoint("TOPLEFT", layer, x2, -y2)
	line:Show()
end

local function Arrow(x, y, dx, dy)
	local len = sqrt(dx * dx + dy * dy)
	if len < 0.01 then return end
	dx, dy = dx / len, dy / len
	Line(2, x - dx * 5 - dy * 3, y - dy * 5 + dx * 3, x, y, 1.6, 0.08, 0.06, 0.03, 1)
	Line(2, x - dx * 5 + dy * 3, y - dy * 5 - dx * 3, x, y, 1.6, 0.08, 0.06, 0.03, 1)
end

local function DrawPath(FDR, path)
	local pts = path.pts
	local n = floor(#pts / 2)
	if n < 2 then return end
	local side = path.kind == "side"
	local t0, t1 = path.t0 or 0, path.t1 or 1
	local count = max(1, n - 1)
	local ax, ay, aIndex = pts[1] * width, pts[2] * height, 1
	local travelled, nextArrow = 0, ARROW_FIRST
	for i = 2, n do
		local x, y = pts[2 * i - 1] * width, pts[2 * i] * height
		local dx, dy = x - ax, y - ay
		local len = sqrt(dx * dx + dy * dy)
		if len >= MIN_SEGMENT or i == n then
			if len > 0 then
				if side then
					local start = -(travelled % (DASH + GAP))
					while start < len do
						local a, b = max(0, start), min(len, start + DASH)
						if b > a then
							Line(1, ax + dx * a / len, ay + dy * a / len, ax + dx * b / len, ay + dy * b / len,
								LINE_SIDE, 0.90, 0.87, 0.75, 1)
						end
						start = start + DASH + GAP
					end
				else
					local t = t0 + ((aIndex - 1) / count) * (t1 - t0)
					local red, green, blue = FDR.GradientColor(t)
					Line(0, ax, ay, x, y, LINE_CASING, 0.05, 0.04, 0.03, 0.85)
					Line(1, ax, ay, x, y, LINE_MAIN, red, green, blue, 1)
					while nextArrow <= travelled + len do
						local f = (nextArrow - travelled) / len
						Arrow(ax + dx * f, ay + dy * f, dx, dy)
						nextArrow = nextArrow + ARROW_STEP
					end
				end
			end
			travelled = travelled + len
			ax, ay, aIndex = x, y, i
		end
	end
end

-- Pins -------------------------------------------------------------------------------------

local function NewPin()
	local pin = CreateFrame("Button", nil, layer)
	pin.bg = pin:CreateTexture(nil, "BACKGROUND")
	pin.bg:SetAllPoints()
	pin.bg:SetTexture(MEDIA .. "circle")
	pin.bg:SetVertexColor(0.05, 0.04, 0.03, 0.92)
	pin.ring = pin:CreateTexture(nil, "ARTWORK")
	pin.ring:SetAllPoints()
	pin.ring:SetTexture(MEDIA .. "ring")
	pin.text = pin:CreateFontString(nil, "OVERLAY")
	pin.text:SetFont(fontFace, 10, "OUTLINE")
	pin.text:SetPoint("CENTER", 0, 0)
	pin.check = pin:CreateTexture(nil, "OVERLAY", nil, 2)
	pin.check:SetTexture(MEDIA .. "check")
	pin:RegisterForClicks("LeftButtonUp")
	pin:SetScript("OnEnter", function(p)
		GameTooltip:SetOwner(p, "ANCHOR_RIGHT")
		GameTooltip:AddLine(p.title or "", 1, 0.82, 0)
		if p.note and p.note ~= "" then GameTooltip:AddLine(p.note, 0.9, 0.9, 0.9, true) end
		if p.hint then GameTooltip:AddLine(p.hint, 0.6, 0.8, 1, true) end
		GameTooltip:Show()
	end)
	pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
	pin:SetScript("OnClick", function(p)
		local ctx = current
		if not (p.toIndex and ctx) then return end
		local FDJ = ctx.FDJ
		if FDJ.ResetDungeonMapView then FDJ.ResetDungeonMapView() end
		FDJ.RenderCustomDungeonMap(ctx.data, p.toIndex)
	end)
	return pin
end

-- kind: "boss" | "rare" | "optional" | "note" | "link"
local function Pin(kind, x, y, label, size, offset)
	usedPins = usedPins + 1
	local pin = pins[usedPins]
	if not pin then pin = NewPin() pins[usedPins] = pin end
	pin:SetFrameLevel(layer:GetFrameLevel() + 3)
	pin:SetSize(size, size)
	pin.text:SetFont(fontFace, max(9, floor(size * 0.55)), "OUTLINE")
	pin.text:SetText(label or "")
	local ring, text = RING[kind] or RING.boss, TEXT[kind] or TEXT.boss
	pin.ring:SetVertexColor(ring[1], ring[2], ring[3])
	pin.text:SetTextColor(text[1], text[2], text[3])
	pin.check:SetSize(size * 0.6, size * 0.6)
	pin.check:ClearAllPoints()
	pin.check:SetPoint("TOPRIGHT", size * 0.2, size * 0.2)
	pin.check:Hide()
	pin:SetAlpha(1)
	pin.title, pin.note, pin.hint, pin.toIndex = nil, nil, nil, nil
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", layer, "TOPLEFT", x * width + offset, -y * height - offset)
	pin:Show()
	return pin
end

-- The journal's own boss pin closest to a route stop on this floor (they are placed by hand, so only roughly equal).
local function NearBoss(data, floorIndex, x, y)
	local best, bestD = nil, 0.08 * 0.08
	for _, boss in ipairs(data.bosses or {}) do
		if (boss.floor or 1) == floorIndex then
			local dx, dy = boss.x - x, boss.y - y
			local d = dx * dx + dy * dy
			if d <= bestD then best, bestD = boss, d end
		end
	end
	return best
end

-- RPG Mode of the journal keeps undiscovered bosses a "???": do not give their names away.
local function StopHidden(ctx, stop)
	local FDJ = ctx.FDJ
	if stop.kind == "optional" or not ctx.dungeonName then return false end
	if not (FDJ.IsRPGMode and FDJ.RPGMapBossHidden) then return false end
	local okMode, on = pcall(FDJ.IsRPGMode)
	if not (okMode and on) then return false end
	local mapBoss = NearBoss(ctx.data, ctx.floorIndex, stop.x, stop.y)
	local record
	if mapBoss then
		local dungeon = FDJ.DB and FDJ.DB[ctx.dungeonName]
		for _, candidate in ipairs((dungeon and dungeon.bosses) or {}) do
			if candidate.name == mapBoss.name then record = candidate break end
		end
	end
	local ok, hidden = pcall(FDJ.RPGMapBossHidden, ctx.dungeonName, record)
	return ok and hidden == true
end

local function LinkPin(ctx, to, x, y, label, size)
	local index = NS.Mapping.FloorIndex(ctx.FDJ, ctx.FDR, ctx.data, to)
	if not index then return end -- the journal has no map for that level
	local pin = Pin("link", x, y, label, size, 0)
	pin.title = ctx.FDR:GetFloorName(to)
	pin.hint = NS.T("gotolevel")
	pin.toIndex = index
end

local function DrawPins(ctx)
	local FDR, route, floorNo, db = ctx.FDR, ctx.route, ctx.fdrFloor, ctx.db
	local size = max(16, floor(ctx.baseH * 0.05))
	local FDJ = ctx.FDJ
	local bossSize = floor(max(26, floor(ctx.baseH * 0.095)) * (FDJ.MapBossScale and FDJ.MapBossScale() or 1))
	local bossOffset = bossSize > 0 and bossSize * 0.42 or 0

	if db.stops then
		local labels = FDR:GetStopLabels(route)
		for i, stop in ipairs(route.stops or {}) do
			if stop.x and stop.y and FDR.OnFloor(stop, floorNo) then
				local isBoss = stop.kind == "boss"
				local kind = (stop.kind == "rare" or stop.kind == "optional") and stop.kind or "boss"
				local hidden = StopHidden(ctx, stop)
				local pin = Pin(kind, stop.x, stop.y, labels[i], isBoss and size or size * 1.1, isBoss and bossOffset or 0)
				pin.title = hidden and "???" or FDR:GetStopName(stop)
				if not hidden then pin.note = FDR.LocText(stop, "note") end
				if FDR:IsStopDone(ctx.key, route, i) then
					pin:SetAlpha(0.55)
					pin.check:Show()
				end
			end
		end
	end

	if db.notes then
		for _, note in ipairs(route.notes or {}) do
			if note.x and note.y and FDR.OnFloor(note, floorNo) then
				local pin = Pin("note", note.x, note.y, "!", size, 0)
				pin.title = FDR.LocText(note, "text") or ""
			end
		end
		for _, note in ipairs(FDR.MapNotes and FDR.MapNotes[floorNo] or {}) do
			if note.x and note.y then
				local pin = Pin("note", note.x, note.y, "!", size, 0)
				pin.title = FDR.LocText(note, "text") or ""
			end
		end
	end

	-- Level changes: explicit links of the route, and the ends of consecutive main paths on different floors.
	local explicit = {}
	for _, link in ipairs(route.links or {}) do
		if link.floor == floorNo and link.to and link.x and link.y then
			explicit[#explicit + 1] = link
			LinkPin(ctx, link.to, link.x, link.y, link.label or ">", size)
		end
	end
	local function Covered(to, x, y)
		for _, link in ipairs(explicit) do
			if link.to == to and (link.x - x) ^ 2 + (link.y - y) ^ 2 < 0.03 * 0.03 then return true end
		end
		return false
	end
	local previous
	for _, path in ipairs(route.paths or {}) do
		if path.kind == "main" and path.pts and #path.pts >= 2 then
			if previous and previous.floor ~= path.floor then
				if previous.floor == floorNo then
					local x, y = previous.pts[#previous.pts - 1], previous.pts[#previous.pts]
					if not Covered(path.floor, x, y) then LinkPin(ctx, path.floor, x, y, ">", size) end
				elseif path.floor == floorNo then
					local x, y = path.pts[1], path.pts[2]
					if not Covered(previous.floor, x, y) then LinkPin(ctx, previous.floor, x, y, "<", size) end
				end
			end
			previous = path
		end
	end
end

-- Public -----------------------------------------------------------------------------------

local function HideUnused()
	for _, pool in pairs(pools) do
		for i = pool.used + 1, #pool.items do pool.items[i]:Hide() end
	end
	for i = usedPins + 1, #pins do pins[i]:Hide() end
end

function Render.Clear()
	current = nil
	if layer then layer:Hide() end
end

-- ctx: FDJ, FDR, db, holder, data, floorIndex, dungeonName, baseH, key, route, fdrFloor
function Render.Draw(ctx)
	local holder = ctx.holder
	width, height = holder:GetSize()
	if not width or not height or width <= 0 or height <= 0 then Render.Clear() return end
	EnsureLayer(holder)
	current = ctx
	for _, pool in pairs(pools) do pool.used = 0 end
	usedPins = 0
	for _, path in ipairs(ctx.route.paths or {}) do
		if path.floor == ctx.fdrFloor and path.pts then DrawPath(ctx.FDR, path) end
	end
	DrawPins(ctx)
	HideUnused()
	layer:Show()
end
