--[[
  Wspolny rdzen addonow z rodziny Odkrywcy (Kupiec, Rybak, Notatki, Slady, Dziennik).
  Kazdy addon ma wlasna kopie tego pliku - dzialaja niezaleznie od siebie.
  Ustawienia addonu przychodza z ns.CONFIG (Locale.lua).
]]
local ADDON_NAME, ns = ...
local C = ns.CONFIG

------------------------------------------------------------------------
-- Pomocnicze
------------------------------------------------------------------------

-- WoW Forever dzieli API z Midnight: niektore wartosci bywaja "sekretne" (np. w walce).
function ns.IsSecret(v)
	if v == nil then return false end
	return issecretvalue ~= nil and issecretvalue(v) or false
end

function ns.Usable(v)
	return v ~= nil and not ns.IsSecret(v)
end

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|c" .. C.color .. C.title .. "|r: " .. msg)
end

function ns.Round(v)
	return math.floor(v * 10000 + 0.5) / 10000
end

------------------------------------------------------------------------
-- Jezyki
------------------------------------------------------------------------

local COMMON = {
	pl = {
		on = "wł.", off = "wył.",
		pins = "Pinezki: %s",
		size_set = "Rozmiar ikon: %d",
		size_bad = "Podaj liczbę 8-40",
		announce = "Komunikaty na czacie: %s",
		lang_set = "Język: polski",
		lang_bad = "Dostępne języki: pl, en",
		accents = "Polskie znaki: %s",
		commands = "komendy:",
		clear_confirm = "To wyczyści: %s. Dopisz 'tak' na końcu komendy.",
		cleared = "Wyczyszczono: %s",
		reset_confirm = "To usunie WSZYSTKIE dane tego addonu. Dopisz 'tak' na końcu komendy.",
		reset_done = "Wszystko usunięte.",
		tt_remove = "Shift + prawy klik: usuń",
		removed = "Usunięto: %s",
		map_fallback = "mapa %s",
		ago_today = "dzisiaj", ago_yesterday = "wczoraj", ago_days = "%d dni temu",
		no_position = "Nie da się tu ustalić pozycji (np. w lochu).",
	},
	en = {
		on = "on", off = "off",
		pins = "Pins: %s",
		size_set = "Icon size: %d",
		size_bad = "Enter a number 8-40",
		announce = "Chat messages: %s",
		lang_set = "Language: English",
		lang_bad = "Available languages: pl, en",
		accents = "Polish characters: %s",
		commands = "commands:",
		clear_confirm = "This will clear: %s. Add 'yes' at the end of the command.",
		cleared = "Cleared: %s",
		reset_confirm = "This will delete ALL data of this addon. Add 'yes' at the end of the command.",
		reset_done = "Everything deleted.",
		tt_remove = "Shift + right-click: remove",
		removed = "Removed: %s",
		map_fallback = "map %s",
		ago_today = "today", ago_yesterday = "yesterday", ago_days = "%d days ago",
		no_position = "Your position can't be determined here (e.g. in a dungeon).",
	},
}

-- Czcionka WoW nie ma polskich liter, wiec domyslnie zamieniamy je na zwykle.
local ACCENT_MAP = {
	["ą"] = "a", ["ć"] = "c", ["ę"] = "e", ["ł"] = "l", ["ń"] = "n", ["ó"] = "o", ["ś"] = "s", ["ź"] = "z", ["ż"] = "z",
	["Ą"] = "A", ["Ć"] = "C", ["Ę"] = "E", ["Ł"] = "L", ["Ń"] = "N", ["Ó"] = "O", ["Ś"] = "S", ["Ź"] = "Z", ["Ż"] = "Z",
}

function ns.Fix(s)
	if ns.db and ns.db.settings.accents == false then
		for from, to in pairs(ACCENT_MAP) do s = s:gsub(from, to) end
	end
	return s
end

local function Lang()
	local lang = ns.db and ns.db.settings.lang or "pl"
	return C.locales[lang] and lang or "pl"
end

function ns.T(key, ...)
	local lang = Lang()
	local s = C.locales[lang][key] or COMMON[lang][key] or C.locales.pl[key] or COMMON.pl[key] or key
	if type(s) ~= "string" then return s end
	if select("#", ...) > 0 then s = s:format(...) end
	return ns.Fix(s)
end

function ns.OnOff(v)
	return v and ("|cff00ff00" .. ns.T("on") .. "|r") or ("|cffff4040" .. ns.T("off") .. "|r")
end

function ns.Ago(t)
	if not t then return "?" end
	local days = math.floor((time() - t) / 86400)
	if days <= 0 then return ns.T("ago_today") end
	if days == 1 then return ns.T("ago_yesterday") end
	return ns.T("ago_days", days)
end

------------------------------------------------------------------------
-- Mapy i pozycja
------------------------------------------------------------------------

function ns.MapName(mapID)
	local info = mapID and C_Map.GetMapInfo(mapID)
	return info and info.name or ns.T("map_fallback", tostring(mapID))
end

-- mapID, x, y gracza (0..1) albo nil
function ns.PlayerPos()
	local mapID = C_Map.GetBestMapForUnit("player")
	if not ns.Usable(mapID) then return end
	local pos = C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then return end
	local x, y = pos:GetXY()
	if not ns.Usable(x) or not ns.Usable(y) or (x == 0 and y == 0) then return end
	return mapID, ns.Round(x), ns.Round(y)
end

-- odleglosc w jardach miedzy dwoma punktami tej samej mapy
function ns.Distance(mapID, x1, y1, x2, y2)
	local w, h = 3000, 2000
	if C_Map.GetMapWorldSize then
		local mw, mh = C_Map.GetMapWorldSize(mapID)
		if mw and mh and mw > 0 and mh > 0 then w, h = mw, mh end
	end
	local dx, dy = (x1 - x2) * w, (y1 - y2) * h
	return math.sqrt(dx * dx + dy * dy)
end

-- najblizsza mapa typu "strefa" (dla podstref, jaskin itp.)
function ns.ZoneMapID(mapID)
	local id, guard = mapID, 0
	while id and guard < 10 do
		local info = C_Map.GetMapInfo(id)
		if not info then return mapID end
		if info.mapType <= Enum.UIMapType.Zone then return id end
		id = info.parentMapID
		guard = guard + 1
	end
	return mapID
end

------------------------------------------------------------------------
-- Baza danych (SavedVariables)
------------------------------------------------------------------------

local BASE_SETTINGS = { lang = "pl", accents = false, hidden = false, size = 18, announce = true }

local function InitDB()
	_G[C.sv] = _G[C.sv] or {}
	local db = _G[C.sv]
	ns.db = db
	db.settings = db.settings or {}
	local s = db.settings
	for _, defaults in ipairs({ C.defaults or {}, BASE_SETTINGS }) do  -- ustawienia addonu maja pierwszenstwo
		for k, v in pairs(defaults) do
			if s[k] == nil then s[k] = type(v) == "table" and CopyTable(v) or v end
		end
	end
	for _, key in ipairs(C.data or {}) do
		db[key] = db[key] or {}
	end
	if not C.locales[s.lang] then s.lang = "pl" end
end

------------------------------------------------------------------------
-- Zdarzenia: ns.On("NAZWA", funkcja). Specjalne: "INIT" (baza gotowa), "LOGIN".
------------------------------------------------------------------------

local handlers = {}
local frame = CreateFrame("Frame")

function ns.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		if event ~= "INIT" and event ~= "LOGIN" then frame:RegisterEvent(event) end
	end
	table.insert(handlers[event], fn)
end

local function Fire(event, ...)
	local list = handlers[event]
	if not list then return end
	for _, fn in ipairs(list) do fn(...) end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" and ... == ADDON_NAME then
		InitDB()
		Fire("INIT")
	elseif event == "PLAYER_LOGIN" then
		if not ns.db then InitDB() end
		ns.charKey = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
		Fire("LOGIN")
	end
	Fire(event, ...)
end)

------------------------------------------------------------------------
-- Mapa swiata: okragle pinezki i dostawca danych
------------------------------------------------------------------------

-- o.icon(data) -> tekstura, o.color(data) -> {r,g,b}, o.tooltip(data, srcMapID), o.name(data), o.remove(data)
function ns.NewPinMixin(o)
	local M = CreateFromMixins(MapCanvasPinMixin)

	function M:OnLoad()
		self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
		self:SetScalingLimits(1, 1.0, 1.2)
		self.Shadow:SetVertexColor(0, 0, 0, 0.75)
		self.Highlight:SetVertexColor(1, 1, 1, 0.25)
	end

	function M:OnAcquired(data, srcMapID, x, y, size)
		self.data, self.srcMapID = data, srcMapID
		self:SetSize(size, size)
		self:SetPosition(x, y)
		self.Icon:SetTexture(o.icon(data))
		self.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local c = o.color(data)
		self.Ring:SetVertexColor(c[1], c[2], c[3], 1)
		self.Highlight:Hide()
	end

	function M:OnMouseEnter()
		if not self.data then return end
		self.Highlight:Show()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		o.tooltip(self.data, self.srcMapID)
		GameTooltip:AddLine(ns.T("tt_remove"), 0.5, 0.5, 0.5)
		GameTooltip:Show()
	end

	function M:OnMouseLeave()
		self.Highlight:Hide()
		GameTooltip:Hide()
	end

	function M:OnMouseUp(button)
		if button == "RightButton" and IsShiftKeyDown() and self.data then
			GameTooltip:Hide()
			if ns.RemoveFromStore(ns.db[C.mapStore], self.data) then
				ns.Print(ns.T("removed", o.name(self.data)))
				ns.RefreshMap()
			end
		end
	end

	return M
end

function ns.RemoveFromStore(store, item)
	for mapID, list in pairs(store) do
		for i = #list, 1, -1 do
			if list[i] == item then
				table.remove(list, i)
				if #list == 0 then store[mapID] = nil end
				return true
			end
		end
	end
end

-- Czy mapa child lezy wewnatrz mapy parent
local ancestry, rects = {}, {}
local function IsDescendant(child, parent)
	local key = child .. ":" .. parent
	if ancestry[key] ~= nil then return ancestry[key] end
	local result, id, guard = false, child, 0
	while id and id ~= 0 and guard < 10 do
		local info = C_Map.GetMapInfo(id)
		if not info then break end
		id = info.parentMapID
		if id == parent then result = true break end
		guard = guard + 1
	end
	ancestry[key] = result
	return result
end

local function ChildRect(child, parent)
	local key = child .. ":" .. parent
	if rects[key] ~= nil then return rects[key] or nil end
	local rect = false
	if IsDescendant(child, parent) and C_Map.GetMapRectOnMap then
		local ok, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, child, parent)
		if ok and minX and maxX and minY and maxY and maxX - minX > 0 and maxY - minY > 0 then
			rect = { minX, maxX, minY, maxY }
		end
	end
	rects[key] = rect
	return rect or nil
end

-- Wywoluje fn(item, srcMapID, x, y, size) dla punktow z store widocznych na mapie uiMapID
-- (punkty tej mapy + punkty map podrzednych, np. stref na kontynencie).
function ns.EachOnMap(store, uiMapID, fn)
	local size = ns.db.settings.size
	local list = store[uiMapID]
	if list then
		for _, item in ipairs(list) do fn(item, uiMapID, item.x, item.y, size) end
	end
	local info = C_Map.GetMapInfo(uiMapID)
	if not info or (info.mapType ~= Enum.UIMapType.Continent and info.mapType ~= Enum.UIMapType.Zone) then return end
	local childSize = info.mapType == Enum.UIMapType.Continent and math.max(8, math.floor(size * 0.6)) or size
	for src, items in pairs(store) do
		if src ~= uiMapID then
			local r = ChildRect(src, uiMapID)
			if r then
				for _, item in ipairs(items) do
					fn(item, src, r[1] + item.x * (r[2] - r[1]), r[3] + item.y * (r[4] - r[3]), childSize)
				end
			end
		end
	end
end

-- ns.EnableMap({ templates = {...}, refresh = function(map, uiMapID) ... end })
local provider, attached
function ns.EnableMap(opts)
	provider = CreateFromMixins(MapCanvasDataProviderMixin)
	function provider:RemoveAllData()
		for _, tpl in ipairs(opts.templates) do self:GetMap():RemoveAllPinsByTemplate(tpl) end
	end
	function provider:OnMapChanged()
		self:RefreshAllData()
	end
	function provider:RefreshAllData()
		self:RemoveAllData()
		if not ns.db or ns.db.settings.hidden then return end
		local uiMapID = self:GetMap():GetMapID()
		if uiMapID then opts.refresh(self:GetMap(), uiMapID) end
	end
	local function Attach()
		if attached or not WorldMapFrame or not WorldMapFrame.AddDataProvider then return end
		WorldMapFrame:AddDataProvider(provider)
		attached = true
		if opts.onAttach then opts.onAttach(WorldMapFrame) end
	end
	ns.On("LOGIN", Attach)
	ns.On("ADDON_LOADED", function(name) if name == "Blizzard_WorldMap" then Attach() end end)
end

function ns.RefreshMap()
	if attached and provider and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

------------------------------------------------------------------------
-- Komendy. Wspolne slowa dzialaja po polsku i angielsku.
------------------------------------------------------------------------

local COMMON_ALIASES = {
	pomoc = "help", help = "help",
	pokaz = "show", ["pokaż"] = "show", show = "show",
	rozmiar = "size", size = "size",
	ogloszenia = "announce", ["ogłoszenia"] = "announce", announce = "announce",
	stat = "stats", stats = "stats", info = "stats",
	wyczysc = "clear", ["wyczyść"] = "clear", clear = "clear",
	reset = "reset",
	jezyk = "lang", ["język"] = "lang", lang = "lang", language = "lang",
	ogonki = "accents", accents = "accents",
}
local YES = { tak = true, yes = true }

function ns.Help()
	ns.Print(ns.T("commands"))
	for _, line in ipairs(C.locales[Lang()].help) do
		DEFAULT_CHAT_FRAME:AddMessage("   " .. ns.Fix(line))
	end
end

-- C.commands: { alias = "cmd" }, C.onCommand(cmd, arg, raw) -> true jesli obsluzone,
-- C.onUnknown(raw) -> dla tekstu, ktory nie jest komenda (np. wyszukiwanie)
local function HandleSlash(msg)
	if not ns.db then return end
	local raw = strtrim(msg or "")
	local word, arg = raw:match("^(%S*)%s*(.-)$")
	word = word:lower()
	local cmd = (C.commands and C.commands[word]) or COMMON_ALIASES[word]
	local s = ns.db.settings

	if C.onCommand and cmd and C.onCommand(cmd, arg, raw) then
		-- obsluzone przez addon
	elseif word == "" or cmd == "help" then
		if C.onEmpty then C.onEmpty() else ns.Help() end
	elseif cmd == "show" then
		s.hidden = not s.hidden
		ns.Print(ns.T("pins", ns.OnOff(not s.hidden)))
	elseif cmd == "size" then
		local n = tonumber(arg)
		if n and n >= 8 and n <= 40 then
			s.size = math.floor(n)
			ns.Print(ns.T("size_set", s.size))
		else
			ns.Print(ns.T("size_bad"))
		end
	elseif cmd == "announce" then
		s.announce = not s.announce
		ns.Print(ns.T("announce", ns.OnOff(s.announce)))
	elseif cmd == "stats" and C.stats then
		C.stats()
	elseif cmd == "clear" and C.clear then
		local what = C.clearLabel and C.clearLabel() or "?"
		if YES[arg:lower()] then
			C.clear()
			ns.Print(ns.T("cleared", what))
		else
			ns.Print(ns.T("clear_confirm", what))
		end
	elseif cmd == "reset" and C.reset then
		if YES[arg:lower()] then
			C.reset()
			ns.Print(ns.T("reset_done"))
		else
			ns.Print(ns.T("reset_confirm"))
		end
	elseif cmd == "lang" then
		local l = arg:lower()
		if C.locales[l] then
			s.lang = l
			ns.Print(ns.T("lang_set"))
		else
			ns.Print(ns.T("lang_bad"))
		end
	elseif cmd == "accents" then
		s.accents = not s.accents
		ns.Print(ns.T("accents", ns.OnOff(s.accents)))
	elseif C.onUnknown then
		C.onUnknown(raw)
	else
		ns.Help()
	end
	ns.RefreshMap()
end

for i, slash in ipairs(C.slash) do
	_G["SLASH_" .. C.slashKey .. i] = slash
end
SlashCmdList[C.slashKey] = HandleSlash
