-- API de WoW simulada, una copia por cliente. CFG lo rellena sim.py.
NOW = 10000
FRAMES, TIMERS, ONUPDATE = {}, {}, {}
DM_SESSIONS, DM_DATA = {}, {}
UNITS, ROSTER, GROUP, RECAP, PLAYERS, SECRETS, FORBIDDEN, CL_EVENT = {}, {}, {}, nil, {}, {}, {}, nil
LEADER, IS_RAID, INST, INST_KIND, COMBAT, ZONE, HK = true, false, false, "none", false, "Baldíos", 0

bit = { band = function(a, b)
    local r, p = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + p end
        a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
    end
    return r
end }
unpack = unpack or table.unpack
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
tostringall = function(...)
    local o = { ... }
    for i = 1, select("#", ...) do o[i] = tostring(o[i]) end
    return unpack(o, 1, select("#", ...))
end
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strsplit = function(sep, s)
    local out, pos = {}, 1
    while true do
        local a, b = s:find(sep, pos, true)
        if not a then out[#out + 1] = s:sub(pos); break end
        out[#out + 1] = s:sub(pos, a - 1)
        pos = b + 1
    end
    return unpack(out)
end
time = os.time; date = os.date
GetTime = function() return NOW end
GetServerTime = function() return 1800000000 + math.floor(NOW) end
debugstack = function() return "" end

---------------------------------------------------------------- frames
local Frame = {}
local function new(kind, name, parent)
    local f = setmetatable({ _kind = kind, _shown = true, _scripts = {}, _events = {}, _enabled = true, _w = 300, _h = 100, _vs = 0 }, Frame)
    FRAMES[#FRAMES + 1] = f
    if name then _G[name] = f end
    return f
end
local M = {}
function M:SetScript(s, fn) self._scripts[s] = fn; if s == "OnUpdate" then ONUPDATE[self] = true end end
function M:GetScript(s) return self._scripts[s] end
function M:HookScript(s, fn) local o = self._scripts[s]; self._scripts[s] = function(...) if o then o(...) end fn(...) end end
function M:RegisterEvent(e)
    if CFG.forever and e == "COMBAT_LOG_EVENT_UNFILTERED" then FORBIDDEN[#FORBIDDEN + 1] = e end
    self._events[e] = true
end
M.RegisterUnitEvent = function(self, e) self._events[e] = true end
function M:UnregisterEvent(e) self._events[e] = nil end
function M:Show() if not self._shown then self._shown = true; local s = self._scripts.OnShow; if s then s(self) end end end
function M:Hide() if self._shown then self._shown = false; local s = self._scripts.OnHide; if s then s(self) end end end
function M:IsShown() return self._shown end
function M:SetShown(v) if v then self:Show() else self:Hide() end end
function M:GetWidth() return self._w end
function M:GetHeight() return self._h end
function M:SetWidth(w) self._w = w end
function M:SetHeight(h) self._h = h end
function M:SetSize(w, h) self._w, self._h = w, h end
function M:GetStringHeight() return 20 end
function M:SetText(t) self._text = t end
function M:GetText() return self._text end
function M:SetChecked(v) self._checked = v and true or false end
function M:GetChecked() return self._checked or false end
function M:Enable() self._enabled = true end
function M:Disable() self._enabled = false end
function M:SetEnabled(v) self._enabled = v and true or false end
function M:IsEnabled() return self._enabled end
function M:SetPoint(...) self._point = { ... } end
function M:SetVerticalScroll(v) self._vs = v end
function M:GetVerticalScroll() return self._vs end
function M:CreateTexture() return new("texture") end
function M:CreateMaskTexture() return new("texture") end
function M:SetAtlas(a) self._atlas = a end
function M:CreateFontString() return new("font") end
function M:GetNormalTexture() return new("texture") end
function M:GetFont() return "font", 12, "" end
function M:Click()
    if not self._enabled then return "disabled" end
    local s = self._scripts.OnClick
    if s then s(self, "LeftButton") end
end
function M:SetVertexColor(r, g, b) self._color = { r, g, b } end
function M:IsMouseOver() return self._over or false end
function M:GetFrameLevel() return 1 end
function M:GetCenter() return 0, 0 end
function M:GetEffectiveScale() return 1 end
Frame.__index = function(t, k)
    if M[k] then return M[k] end
    if type(k) == "string" and k:sub(1, 1):match("%u") then return function() end end
    return nil
end
function CreateFrame(kind, name, parent, template)
    if CFG.strict and template == "UIRadioButtonTemplate" then error("plantilla desconocida") end
    return new(kind, name, parent)
end
UIParent = new("Frame"); Minimap = new("Frame"); GameTooltip = new("Frame")
UISpecialFrames = {}

---------------------------------------------------------------- mapa del mundo
TIP = {}
GameTooltip.SetOwner = function() TIP = {} end
GameTooltip.AddLine = function(_, text) TIP[#TIP + 1] = text end
-- [mapa] = instancia y rectángulo dentro de su continente. 1414 y 1415 son continentes, 947 es el mundo entero.
MAPS = {
    [1411] = { inst = 1, x = 0.4, y = 0.4, w = 0.1, h = 0.2 },
    [1414] = { inst = 1, x = 0, y = 0, w = 1, h = 1 },
    [1415] = { inst = 0, x = 0, y = 0, w = 1, h = 1 },
}
MAP_ID, POS_X, POS_Y = 1411, 0.5, 0.5
local function vec(x, y) return { x = x, y = y, GetXY = function(s) return s.x, s.y end } end
CreateVector2D = vec
C_Map = {
    GetBestMapForUnit = function() return MAP_ID end,
    GetPlayerMapPosition = function() if POS_X then return vec(POS_X, POS_Y) end end,
    GetWorldPosFromMapPos = function(id, v)
        local m = MAPS[id]
        if m then return m.inst, vec(m.x + v.x * m.w, m.y + v.y * m.h) end
    end,
    GetMapPosFromWorldPos = function(inst, world, id)
        local m = MAPS[id]
        if m and m.inst == inst then return id, vec((world.x - m.x) / m.w, (world.y - m.y) / m.h) end
    end,
    GetMapRectOnMap = function(id, top)
        if id == 1411 and top == 947 then return 0.2, 0.3, 0.1, 0.2 end
        return 0, 0, 0, 0
    end,
}
MapCanvasDataProviderMixin = {
    OnAdded = function(self, map) self.owningMap = map end,
    GetMap = function(self) return self.owningMap end,
    OnShow = function() end, OnHide = function() end,
    RefreshAllData = function() end,
    OnMapChanged = function(self) self:RefreshAllData() end,
}
function CreateFromMixins(...)
    local out = {}
    for _, mixin in ipairs({ ... }) do
        for k, v in pairs(mixin) do out[k] = v end
    end
    return out
end
WorldMapFrame = new("Frame", "WorldMapFrame")
WorldMapFrame._shown, WorldMapFrame._map, WorldMapFrame._scale = false, 1411, 1
WorldMapFrame._canvas = new("Frame")
WorldMapFrame._providers = {}
function WorldMapFrame:GetCanvas() return self._canvas end
function WorldMapFrame:GetMapID() return self._map end
function WorldMapFrame:GetCanvasScale() return self._scale end
function WorldMapFrame:AddDataProvider(p) self._providers[#self._providers + 1] = p; p:OnAdded(self) end
function WorldMapFrame:SetMapID(id)
    self._map = id
    for _, p in ipairs(self._providers) do p:OnMapChanged() end
end
function WorldMapFrame:SetCanvasScale(s)
    self._scale = s
    for _, p in ipairs(self._providers) do p:OnCanvasScaleChanged() end
end
WorldMapFrame:SetScript("OnShow", function(self) for _, p in ipairs(self._providers) do p:OnShow() end end)
WorldMapFrame:SetScript("OnHide", function(self) for _, p in ipairs(self._providers) do p:OnHide() end end)

DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) py_print(m) end }
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
SOUNDKIT = {}
PlaySound = function() end
StaticPopup_Hide = function() end
StaticPopup_Resize = function() end

function lua_fire(e, ...)
    for _, f in ipairs(FRAMES) do
        if f._events[e] and f._scripts.OnEvent then
            local ok, err = pcall(f._scripts.OnEvent, f, e, ...)
            if not ok then py_error(tostring(err)) end
        end
    end
end

C_Timer = {
    After = function(s, fn) TIMERS[#TIMERS + 1] = { t = NOW + s, fn = fn } end,
    NewTicker = function(s, fn)
        local tk = { Cancel = function(self) self.dead = true end }
        TIMERS[#TIMERS + 1] = { t = NOW + s, fn = fn, every = s, tk = tk }
        return tk
    end,
}

function lua_tick(now)
    NOW = now
    local due = {}
    for i = #TIMERS, 1, -1 do
        local t = TIMERS[i]
        if t.tk and t.tk.dead then
            table.remove(TIMERS, i)
        elseif t.t <= now then
            due[#due + 1] = t
            if t.every then t.t = now + t.every else table.remove(TIMERS, i) end
        end
    end
    for i = #due, 1, -1 do
        local ok, err = pcall(due[i].fn)
        if not ok then py_error(tostring(err)) end
    end
    for f in pairs(ONUPDATE) do
        if f._shown then
            local ok, err = pcall(f._scripts.OnUpdate, f, 0.1)
            if not ok then py_error(tostring(err)) end
        end
    end
end

---------------------------------------------------------------- jugador y unidades
local function P() return UNITS.player end
function GetBuildInfo() return "x", "y", "z", CFG.forever and 16001 or 11508 end
function UnitName(u)
    local x = UNITS[u]
    if not x then return nil end
    return x.first, x.second
end
function UnitClass(u) local x = UNITS[u]; if x then return x.class, x.class end end
function UnitLevel(u) local x = UNITS[u]; return x and x.level or 0 end
function UnitFactionGroup(u) local x = UNITS[u]; if x then return x.faction, x.faction end end
function UnitGUID(u) local x = UNITS[u]; return x and x.guid end
function UnitExists(u) return UNITS[u] ~= nil end
function UnitIsPlayer(u) local x = UNITS[u]; return x and x.isPlayer end
function UnitIsDeadOrGhost(u) local x = UNITS[u]; return x and x.dead end
function UnitIsUnit(a, b) return UNITS[a] ~= nil and UNITS[a] == UNITS[b] end
function UnitIsGhost() return false end
function UnitIsAFK() return false end
function UnitAffectingCombat() return COMBAT end
function InCombatLockdown() return COMBAT end
function UnitTokenFromGUID(guid)
    if not CFG.forever then return nil end
    for u, x in pairs(UNITS) do if x.guid == guid then return u end end
end
if true then
    function lua_initForever()
        if CFG.forever then
            issecretvalue = function(v) return SECRETS[v] == true end
            C_Spell = { GetSpellName = function(id) return "Hechizo" .. tostring(id) end }
            C_DamageMeter = {
                GetAvailableCombatSessions = function() return DM_SESSIONS end,
                GetCombatSessionFromID = function(id, kind) return DM_DATA[id] end,
            }
            Enum = { DamageMeterType = { HealingDone = 2 } }
            COMBATLOG_XPGAIN_FIRSTPERSON = "%s muere, ganas %d puntos de experiencia."
            C_DeathRecap = {
                HasRecapEvents = function() return RECAP ~= nil end,
                GetRecapEvents = function() return RECAP end,
            }
        end
    end
end
function GetPlayerInfoByGUID(guid)
    local p = PLAYERS[guid]
    if p then return p.class, p.class, p.race, p.race, 2, p.name, "Reino" end
end
function GetPVPLifetimeStats() return HK, 0, 0 end
function CombatLogGetCurrentEventInfo() return unpack(CL_EVENT) end

---------------------------------------------------------------- guild y grupo
function IsInGuild() return true end
function GetGuildInfo() return "Los Solfamidas", "Rango", 1 end
function GetNumGuildMembers() return #ROSTER end
function GetGuildRosterInfo(i)
    local r = ROSTER[i]
    if r then return r.raw, "Rango", r.rankIndex, r.level, r.class, r.zone, "", "", r.online, 0, r.class end
end
C_GuildInfo = { GuildRoster = function() TIMERS[#TIMERS + 1] = { t = NOW + 0.05, fn = function() lua_fire("GUILD_ROSTER_UPDATE") end } end }
SetGuildRosterShowOffline = function() end
GuildControlGetNumRanks = function() return 3 end
GuildControlGetRankName = function(i) return "Rango" .. i end
function IsInGroup() return #GROUP > 0 end
function IsInRaid() return IS_RAID end
function GetNumGroupMembers() return #GROUP end
function UnitIsGroupLeader() return LEADER end
function IsInInstance() return INST, INST_KIND end
C_PartyInfo = {
    InviteUnit = function(n) py_invite(n) end,
    LeaveParty = function() py_leave() end,
    ConvertToRaid = function() py_convert() end,
}
AcceptGroup = function() py_accept() end
-- members = { { first, second, ... } } sin contarme a mí; se montan party/raid
function lua_setGroup(list, leader, raid)
    for k in pairs(UNITS) do if k:match("^party") or k:match("^raid") then UNITS[k] = nil end end
    GROUP = {}
    LEADER, IS_RAID = leader, raid
    if list then
        for i, m in pairs(list) do GROUP[#GROUP + 1] = m end
        local n = #GROUP
        for i = 1, n do
            local m = GROUP[i]
            local u = { first = m.first, second = m.second, isPlayer = true, faction = "Horde", class = "MAGE", level = 20, guid = m.guid }
            UNITS[(raid and "raid" or "party") .. i] = u
        end
        if n > 0 then
            GROUP[#GROUP + 1] = { me = true }
            if raid then UNITS["raid" .. (n + 1)] = UNITS.player end
        end
    end
    lua_fire("GROUP_ROSTER_UPDATE")
end
Ambiguate = function(n) return (n:gsub("%-Reino$", "")) end
C_ChatInfo = {
    PerformEmote = function() return false end,
    RegisterAddonMessagePrefix = function() end,
    SendAddonMessage = function(pre, text, chan, target) py_send(text, chan, target) end,
}
SendChatMessage = function(msg, chan, _, target) py_chat(msg, chan, target) end
GetMoney = function() return 0 end
GetRealZoneText = function() return ZONE end
GetZoneText = function() return ZONE end
GetSubZoneText = function() return "" end
GetZonePVPInfo = function() return "contested" end
IsSwimming = function() return false end
IsFlying = function() return false end
RequestTimePlayed = function() end
GetCursorPosition = function() return 0, 0 end
GetSpellInfo = function(id) return "Hechizo" .. tostring(id) end
RandomRoll = function() end
DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel"
DUEL_WINNER_RETREAT = "%2$s has fled from %1$s in a duel"
InspectUnit = function() end
-- como en Forever: una envoltura antigua que llama a la función nueva
DoEmote = function(token, target) return C_ChatInfo.PerformEmote(token, target) end
hooksecurefunc = function(a, b, c)
    if type(a) == "table" then local o = a[b]; if o then a[b] = function(...) local r = o(...); c(...); return r end end
    elseif _G[a] then local o = _G[a]; _G[a] = function(...) local r = o(...); b(...); return r end end
end
function lua_load(src, name, ns)
    local f, err = loadstring(src, name)
    if not f then py_error("SINTAXIS " .. name .. ": " .. tostring(err)); return end
    local ok, e = pcall(f, "SolfaGuild", ns)
    if not ok then py_error("CARGA " .. name .. ": " .. tostring(e)) end
end
SlashCmdList = {}
ChatFrame_AddMessageEventFilter = function() end

function lua_strict()
    CFG.strict = true
    ChatFrame_AddMessageEventFilter, GetZonePVPInfo, StaticPopup_Resize, StaticPopup_Hide, GetSpellInfo = nil, nil, nil, nil, nil
    ChatFrameUtil = { AddMessageEventFilter = function() end }
end
