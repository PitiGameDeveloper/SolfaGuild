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

-- Forever y Midnight prohíben a los addons el registro de combate: registrar
-- COMBAT_LOG_EVENT_UNFILTERED saca un aviso de "bloqueado" al jugador.
local INTERFACE = select(4, GetBuildInfo())
SG.HasCombatLog = not (INTERFACE >= 120000 or (INTERFACE >= 16000 and INTERFACE < 20000))
-- En Forever los personajes tienen nombre y apellido
SG.IsForever = INTERFACE >= 16000 and INTERFACE < 20000

---------------------------------------------------------------------------
-- Errores: se avisan en el chat (una vez por sesión) y se guardan en
-- SolfaGuildDB.errors para poder revisarlos fuera del juego.
---------------------------------------------------------------------------
local seenErrors = {}
local pendingErrors = {}   -- errores de antes de cargar la base de datos

function SG:ReportError(err, stack)
    err = tostring(err)
    local list = SolfaGuildDB and SolfaGuildDB.errors or pendingErrors
    table.insert(list, { t = time(), v = SG.version, err = err, stack = stack })
    while #list > 20 do table.remove(list, 1) end
    if not seenErrors[err] then
        seenErrors[err] = true
        DEFAULT_CHAT_FRAME:AddMessage(SG.ICON .. " " .. SG.COLOR .. "SolfaGuild|r |cffff5555error:|r " .. err)
    end
end

-- Ejecuta fn protegida; si falla, informa del error. Devuelve true si fue bien.
function SG:Try(fn, ...)
    local args, n = { ... }, select("#", ...)
    return xpcall(function() return fn(unpack(args, 1, n)) end, function(err)
        SG:ReportError(err, debugstack and debugstack(2, 12, 0) or nil)
    end)
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
SG.frame = frame
local handlers = {}

function SG:On(event, fn)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" and not self.HasCombatLog then return end
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
        SG:Try(list[i], ...)
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
        SG:Try(list[i], ...)
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

-- Nombre de un personaje sin reino: es la clave con la que se guarda todo.
-- Forever: "Nombre Apellido". Según de dónde venga llega como "Nombre Apellido-Reino",
-- "Nombre-Apellido" o "Nombre-Apellido-Reino". Classic Era: "Nombre" o "Nombre-Reino".
function SG:Short(name)
    if not name then return nil end
    if Ambiguate then name = Ambiguate(name, "none") end
    local first, second = strsplit("-", name)
    if self.IsForever and second and second ~= "" and not first:find(" ", 1, true) then
        return first .. " " .. second
    end
    return first
end

-- Valor que el juego puede ocultar en Forever (con esos no se puede operar): nil
function SG:Open(v)
    if v ~= nil and issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Nombre de una unidad, igual que SG:Short. nil si no existe o el juego lo oculta.
function SG:UnitFull(unit)
    local a, b = UnitName(unit)
    a, b = self:Open(a), self:Open(b)
    if not a or a == "" then return nil end
    -- la segunda parte es el apellido en Forever y el reino en Classic Era
    if self.IsForever and b and b ~= "" then return a .. " " .. b end
    return a
end

function SG:MyName()
    return self:UnitFull("player") or (UnitName("player"))
end

-- Forma de escribir un nombre que el juego acepta para susurrar o invitar: la que
-- él mismo nos ha dado. Primero la del último mensaje recibido, luego la del roster.
SG.rawNames = {}
function SG:Target(name)
    local r = self.roster and self.roster[name]
    return self.rawNames[name] or (r and r.full) or name
end

-- Unidad de un compañero de grupo. Por nombre UnitInParty no siempre vale con
-- apellidos: se mira uno a uno. El juego a veces da solo el nombre, sin apellido.
function SG:GroupUnit(name)
    if not IsInGroup() then return nil end
    local raid = IsInRaid()
    for i = 1, GetNumGroupMembers() do
        local unit = raid and ("raid" .. i) or ("party" .. i)
        if UnitExists(unit) then
            if self:UnitFull(unit) == name or self:Open((UnitName(unit))) == name then return unit end
        end
    end
end

function SG:InMyGroup(name)
    return self:GroupUnit(name) ~= nil
end

-- Resumen de muerte del juego: la entrada más reciente es el golpe final
function SG:LastRecap()
    local DR = C_DeathRecap
    if not (DR and DR.HasRecapEvents and self:Open(DR.HasRecapEvents())) then return nil end
    local list = DR.GetRecapEvents()
    if type(list) ~= "table" then return nil end
    local best, bestT
    for _, ev in ipairs(list) do
        local t = self:Open(ev.timestamp) or 0
        if not best or t >= bestT then best, bestT = ev, t end
    end
    return best
end

function SG:GuildName()
    local g = GetGuildInfo("player")
    return g
end

-- Clave de semana: la semana empieza con el reinicio semanal del WoW (los
-- miércoles en Europa). La clave es la fecha (AAAA-MM-DD) del último reinicio.
local RESET_WDAY, RESET_HOUR = 4, 5   -- miércoles (1 = domingo) a las 05:00, si el juego no lo dice
function SG:WeekKey()
    local now = time()
    local untilReset = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
        and C_DateAndTime.GetSecondsUntilWeeklyReset()
    local last
    if untilReset and untilReset > 0 then
        last = now + untilReset - 7 * 86400
    else
        local d = date("*t", now)
        local back = (d.wday - RESET_WDAY) % 7
        last = time({ year = d.year, month = d.month, day = d.day - back, hour = RESET_HOUR, min = 0, sec = 0 })
        if last > now then last = last - 7 * 86400 end
    end
    -- redondeo a la hora para que no baile por segundos
    last = math.floor((last + 1800) / 3600) * 3600
    return date("%Y-%m-%d", last)
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

-- withSeconds: añade los segundos (para desempatar en Cositas)
function SG:FormatTime(seconds, withSeconds)
    seconds = math.floor(tonumber(seconds) or 0)
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local out
    if d > 0 then out = string.format("%dd %dh %dm", d, h, m)
    else out = string.format("%dh %dm", h, m) end
    if withSeconds then out = out .. string.format(" %ds", seconds % 60) end
    return out
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
            SG:Try(fn)
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
        milestones = {},    -- [clave] = timestamp (hitos ya celebrados, por jugador)
        isGMAccount = {},   -- [guild] = true si esta cuenta tiene al GM
    },
    guilds = {},            -- [guild] = { accounts, seen, settings, events, gmAccount }
    zoneNotify = {},        -- [zona] = timestamp
    ui = { minimapAngle = 200, hideMinimap = false },
    debug = false,
    errors = {},            -- últimos errores (ver SG:ReportError)
}

function SG:InitDB()
    SolfaGuildDB = SolfaGuildDB or {}
    self:CopyDefaults(SolfaGuildDB, DB_DEFAULTS)
    self.db = SolfaGuildDB
    self.db.my.dhNotified = nil   -- de versiones anteriores (ayudante de mazmorras)
    for _, e in ipairs(pendingErrors) do table.insert(self.db.errors, e) end
    wipe(pendingErrors)
    if not self.db.accountId then
        self.db.accountId = self:RandomId(12)
        -- datos vacíos (addon nuevo o WTF borrado): se intenta recuperar la
        -- cuenta desde la guild antes de enviar nada (ver Players.lua)
        self.restoring = true
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
        kills = 0, killsWeek = 0, dungeonsWeek = 0, weekKey = "",
        zones = {}, zonesWeek = {}, teams = {}, teamsWeek = {},
        earned = 0,
        dungeons = {},
        played = 0,
        cositas = {},
        updated = 0,
    })
    return c
end

---------------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------------
SG:On("ADDON_LOADED", function(name)
    if name ~= ADDON_NAME then return end
    SG:InitDB()
    for _, mod in ipairs(SG.modules) do
        if mod.OnInit then
            SG:Try(mod.OnInit, mod)
        end
    end
end)

SG:On("PLAYER_LOGIN", function()
    -- de versiones anteriores, que en Forever guardaban solo el nombre sin apellido
    local first, full = (UnitName("player")), SG:MyName()
    local chars = SG.db.my.chars
    if first ~= full and chars[first] and not chars[full] then
        chars[full], chars[first] = chars[first], nil
        if SG.db.my.main == first then SG.db.my.main = full end
    end
    local c = SG:MyChar()
    c.class = select(2, UnitClass("player"))
    c.level = UnitLevel("player")
    if not SG.db.my.main then SG.db.my.main = SG:MyName() end
    for _, mod in ipairs(SG.modules) do
        if mod.OnLogin then
            SG:Try(mod.OnLogin, mod)
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
local function slash(msg)
    msg = strtrim(msg or ""):lower()
    if not SG.db then
        SG:Print("|cffff5555El addon no se ha iniciado bien.|r Haz /reload y mira si sale algún error en el chat.")
        return
    end
    if msg == "debug" then
        SG.db.debug = not SG.db.debug
        SG:Print("Debug:", SG.db.debug and "ON" or "OFF")
    elseif msg == "sync" then
        SG:Fire("REQUEST_SYNC")
        SG:Print("Sincronizando con la guild...")
    elseif msg == "minimap" then
        SG.db.ui.hideMinimap = not SG.db.ui.hideMinimap
        SG:Fire("MINIMAP_TOGGLE")
    elseif msg == "recuperar" then
        SG:RequestRestore()
    elseif msg == "test" then
        SG:Fire("TEST_POPUP")
    elseif msg == "campeo" then
        SG:Fire("TEST_CAMP")
    elseif msg == "lfs" then
        SG:Fire("TEST_LFS")
    else
        if SG.UI and SG.UI.Toggle then SG.UI:Toggle() end
    end
end

-- protegido: si algo falla, el chat se cierra igual y el error sale en el chat
SlashCmdList["SOLFAGUILD"] = function(msg) SG:Try(slash, msg) end
