--[[
  Slady - rysuje na mapie swiata sciezki, ktorymi naprawde przeszedles.
  Mapa jest dzielona na siatke 200x200; kazde odwiedzone pole zostaje zapamietane.
]]
local _, ns = ...
local C, T = ns.CONFIG, ns.T

local GRID = 200
local INTERVAL = 2          -- co ile sekund sprawdzamy pozycje
local MAX_DOTS = 12000      -- limit kropek rysowanych na jednej mapie
local DOT_COLOR = { 0.86, 0.27, 0.16, 0.65 }
local DOT_TEXTURE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

------------------------------------------------------------------------
-- Zapisywanie
------------------------------------------------------------------------

local function Record()
	if not ns.db or not ns.db.settings.record then return end
	if UnitOnTaxi and UnitOnTaxi("player") then return end
	local mapID, x, y = ns.PlayerPos()
	if not mapID then return end
	local cx = math.min(GRID - 1, math.floor(x * GRID))
	local cy = math.min(GRID - 1, math.floor(y * GRID))
	local key = cx * 1000 + cy
	local cells = ns.db.trails[mapID]
	if not cells then
		cells = {}
		ns.db.trails[mapID] = cells
	end
	if not cells[key] then
		cells[key] = true
		if WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == mapID then ns.RefreshMap() end
	end
end

ns.On("LOGIN", function()
	C_Timer.NewTicker(INTERVAL, Record)
end)

------------------------------------------------------------------------
-- Rysowanie: jedna "pinezka" wielkosci calej mapy z kropkami w srodku
------------------------------------------------------------------------

SladyTrailPinMixin = CreateFromMixins(MapCanvasPinMixin)

function SladyTrailPinMixin:OnLoad()
	self:UseFrameLevelType("PIN_FRAME_LEVEL_MAP_HIGHLIGHT")
	self:EnableMouse(false)
	self.dots = {}
end

function SladyTrailPinMixin:OnAcquired(cells)
	local map = self:GetMap()
	-- gdyby mapa nie znala poziomu MAP_HIGHLIGHT, uzyj zwyklego poziomu ikon
	local mgr = map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
	if mgr and mgr.frameLevels and mgr.frameLevels["PIN_FRAME_LEVEL_MAP_HIGHLIGHT"] == nil then
		self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
	end

	local w, h
	if map.DenormalizeHorizontalSize then
		w, h = map:DenormalizeHorizontalSize(1.0), map:DenormalizeVerticalSize(1.0)
	else
		w, h = map:GetCanvas():GetSize()
	end
	self:SetSize(w, h)
	self:SetPosition(0.5, 0.5)

	local size = math.max(2, w / GRID * 2.2)
	local used = 0
	for key in pairs(cells) do
		used = used + 1
		if used > MAX_DOTS then break end
		local dot = self.dots[used]
		if not dot then
			dot = self:CreateTexture(nil, "OVERLAY")
			dot:SetTexture(DOT_TEXTURE)
			dot:SetVertexColor(DOT_COLOR[1], DOT_COLOR[2], DOT_COLOR[3], DOT_COLOR[4])
			self.dots[used] = dot
		end
		local cx, cy = math.floor(key / 1000), key % 1000
		dot:SetSize(size, size)
		dot:ClearAllPoints()
		dot:SetPoint("CENTER", self, "TOPLEFT", (cx + 0.5) / GRID * w, -(cy + 0.5) / GRID * h)
		dot:Show()
	end
	for i = math.min(used, MAX_DOTS) + 1, #self.dots do self.dots[i]:Hide() end
end

ns.EnableMap({
	templates = { "SladyTrailPinTemplate" },
	refresh = function(map, uiMapID)
		local cells = ns.db.trails[uiMapID]
		if cells and next(cells) then map:AcquirePin("SladyTrailPinTemplate", cells) end
	end,
})

------------------------------------------------------------------------
-- Komendy
------------------------------------------------------------------------

C.onCommand = function(cmd)
	if cmd == "record" then
		ns.db.settings.record = not ns.db.settings.record
		ns.Print(T("record", ns.OnOff(ns.db.settings.record)))
		return true
	end
end

C.stats = function()
	local cells, maps = 0, 0
	for _, set in pairs(ns.db.trails) do
		maps = maps + 1
		for _ in pairs(set) do cells = cells + 1 end
	end
	ns.Print(T("stats", cells, maps))
end

C.clearLabel = function()
	local mapID = ns.PlayerPos()
	return mapID and ns.MapName(mapID) or "?"
end
C.clear = function()
	local mapID = ns.PlayerPos()
	if mapID then ns.db.trails[mapID] = nil end
end
C.reset = function() ns.db.trails = {} end
