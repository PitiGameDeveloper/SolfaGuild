-- SolfaGuild - Core
-- Namespace, base de datos, despachador de eventos y utilidades comunes.

local ADDON_NAME, ns = ...

local SG = {}
ns.SG = SG
_G.SolfaGuild = SG

SG.name    = ADDON_NAME
SG.version = "0.1.0"
SG.PREFIX  = "SolfaGuild"
SG.ICON    = "|TInterface\\AddOns\\SolfaGuild\\Media\\clef:14:14|t"
SG.ICON_PATH = "Interface\\AddOns\\SolfaGuild\\Media\\clef"
SG.COLOR   = "|cffb48cff"

SG.modules = {}

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
SG.frame = frame
local handlers = {}

function SG:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        frame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then geterrorhandler()(err) end
    end
end)

-- Callbacks internos (no son eventos del juego)
local callbacks = {}
function SG:Listen(name, fn)
    callbacks[name] = callbacks[name] or {}
    table.insert(callbacks[name], fn)
end
function SG:Fire(name, ...)
    local list = callbacks[name]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then geterrorhandler()(err) end
    end
end

function SG:RegisterModule(name, mod)
    mod.name = name
    self.modules[name] = mod
    table.insert(self.modules, mod)
    return mod
end

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
function SG:Print(...)
    local msg = strjoin(" ", tostringall(...))
    DEFAULT_CHAT_FRAME:AddMessage(SG.ICON .. " " .. SG.COLOR .. "SolfaGuild|r: " .. msg)
end

function SG:Debug(...)
    if SolfaGuildDB and SolfaGuildDB.debug then
        self:Print("|cff888888[debug]|r", ...)
    end
end

function SG:Now()
    return GetServerTime and GetServerTime() or time()
end

-- Nombre corto sin reino
function SG:Short(name)
    if not name then return nil end
    if Ambiguate then name = Ambiguate(name, "none") end
    return (strsplit("-", name))
end

function SG:MyName()
    return (UnitName("player"))
end

function SG:GuildName()
    local g = GetGuildInfo("player")
    return g
end

-- Clave de semana (lunes a domingo)
function SG:WeekKey(t)
    return date("%Y-%W", t or time())
end

-- 787226033 -> "7.872o 26p 33c"
local function thousands(n)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
    if out:sub(1, 1) == "." then out = out:sub(2) end
    return out
end
SG.Thousands = thousands

local DAYS = { "Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb" }
function SG:DayName(t)
    return DAYS[tonumber(date("%w", t)) + 1]
end

function SG:FormatMoney(copper, colored)
    copper = math.floor(tonumber(copper) or 0)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if colored then
        return string.format("|cffffd700%so|r |cffc7c7cf%dp|r |cffeda55f%dc|r", thousands(g), s, c)
    end
    return string.format("%so %dp %dc", thousands(g), s, c)
end

function SG:FormatTime(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if d > 0 then return string.format("%dd %dh %dm", d, h, m) end
    return string.format("%dh %dm", h, m)
end

function SG:ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then
        return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
    end
    return "|cffffffff"
end

function SG:InCombat()
    return InCombatLockdown() or UnitAffectingCombat("player")
end

-- Ejecuta fn cuando el jugador no esté en combate
local afterCombat = {}
function SG:WhenOutOfCombat(fn)
    if not self:InCombat() then
        fn()
    else
        table.insert(afterCombat, fn)
    end
end
SG:On("PLAYER_REGEN_ENABLED", function()
    -- pequeño margen para que no salte justo al salir de combate
    C_Timer.After(1.5, function()
        if SG:InCombat() then return end
        local list = afterCombat
        afterCombat = {}
        for _, fn in ipairs(list) do
            local ok, err = pcall(fn)
            if not ok then geterrorhandler()(err) end
        end
    end)
end)

function SG:CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            self:CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function SG:RandomId(len)
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local t = {}
    for i = 1, (len or 10) do
        local r = math.random(1, #chars)
        t[i] = chars:sub(r, r)
    end
    return table.concat(t)
end

function SG:Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- Base de datos (SavedVariables de cuenta => los alters se conocen solos)
---------------------------------------------------------------------------
local DB_DEFAULTS = {
    accountId = nil,
    my = {
        main = nil,         -- nombre del main elegido
        chars = {},         -- [nombre] = datos completos del personaje
        manualAlts = {},    -- [nombre] = true (alters aún no logueados con el addon)
        milestones = {},    -- [clave] = timestamp (hitos ya celebrados, por jugador)
        dhNotified = {},    -- [char..dungeon] = true
        isGMAccount = {},   -- [guild] = true si esta cuenta tiene al GM
    },
    guilds = {},            -- [guild] = { accounts, seen, settings, events, gmAccount }
    zoneNotify = {},        -- [zona] = timestamp
    ui = { minimapAngle = 200, hideMinimap = false },
    debug = false,
}

function SG:InitDB()
    SolfaGuildDB = SolfaGuildDB or {}
    self:CopyDefaults(SolfaGuildDB, DB_DEFAULTS)
    self.db = SolfaGuildDB
    if not self.db.accountId then
        self.db.accountId = self:RandomId(12)
    end
end

function SG:GuildDB()
    local g = self:GuildName()
    if not g then return nil end
    local gdb = self.db.guilds[g]
    if not gdb then
        gdb = { accounts = {}, seen = {}, settings = {}, events = {}, gmAccount = nil }
        self.db.guilds[g] = gdb
    end
    gdb.accounts = gdb.accounts or {}
    gdb.seen = gdb.seen or {}
    gdb.settings = gdb.settings or {}
    gdb.events = gdb.events or {}
    return gdb
end

-- Datos del personaje actual (se crean si no existen)
function SG:MyChar()
    local name = self:MyName()
    local c = self.db.my.chars[name]
    if not c then
        c = {}
        self.db.my.chars[name] = c
    end
    self:CopyDefaults(c, {
        class = select(2, UnitClass("player")),
        level = UnitLevel("player"),
        guild = nil,
        kills = 0, killsWeek = 0, weekKey = "",
        zones = {}, partners = {},
        gold = 0, earned = 0,
        dungeons = {},
        played = 0,
        updated = 0,
    })
    return c
end

---------------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------------
SG:On("ADDON_LOADED", function(name)
    if name ~= ADDON_NAME then return end
    math.randomseed(time() + math.floor(GetTime() * 1000))
    SG:InitDB()
    for _, mod in ipairs(SG.modules) do
        if mod.OnInit then
            local ok, err = pcall(mod.OnInit, mod)
            if not ok then geterrorhandler()(err) end
        end
    end
end)

SG:On("PLAYER_LOGIN", function()
    local c = SG:MyChar()
    c.class = select(2, UnitClass("player"))
    c.level = UnitLevel("player")
    if not SG.db.my.main then SG.db.my.main = SG:MyName() end
    for _, mod in ipairs(SG.modules) do
        if mod.OnLogin then
            local ok, err = pcall(mod.OnLogin, mod)
            if not ok then geterrorhandler()(err) end
        end
    end
    SG:Print("v" .. SG.version .. " cargado. Escribe |cffffff00/solfa|r para abrir la ventana.")
end)

SG:On("PLAYER_LEVEL_UP", function(level)
    SG:MyChar().level = level
end)

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
SLASH_SOLFAGUILD1 = "/solfa"
SLASH_SOLFAGUILD2 = "/sg"
SlashCmdList["SOLFAGUILD"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "debug" then
        SG.db.debug = not SG.db.debug
        SG:Print("Debug:", SG.db.debug and "ON" or "OFF")
    elseif msg == "sync" then
        SG:Fire("REQUEST_SYNC")
        SG:Print("Sincronizando con la guild...")
    elseif msg == "minimap" then
        SG.db.ui.hideMinimap = not SG.db.ui.hideMinimap
        SG:Fire("MINIMAP_TOGGLE")
    elseif msg == "test" then
        SG:Fire("TEST_POPUP")
    else
        if SG.UI and SG.UI.Toggle then SG.UI:Toggle() end
    end
end
