-- SolfaGuild - Ajustes de guild controlados por el GM (desde cualquiera de sus alters)
-- Admins = todos los personajes de la cuenta que contiene al Guild Master (rango 0).

local _, ns = ...
local SG = ns.SG
local Comm = SG.Comm

local S = SG:RegisterModule("Settings", {})
SG.Settings = S

S.defaults = {
    ver = 0, by = "",
    features = {
        pvp = true, gold = true, dungeons = true, playtime = true,
        dungeonHelper = true, whisperIcon = true, inviteIcon = true,
        zoneNotify = true, events = true, campSOS = true,
    },
    zoneCooldown = 30,      -- minutos entre avisos de la misma zona
    eventReminder = 10,     -- minutos de antelación del aviso de evento
    campDeaths = 2,         -- muertes a manos de enemigos para considerar campeo...
    campWindow = 10,        -- ...dentro de estos minutos
    dhBelow = 2,            -- niveles por debajo del nivel de desbloqueo
    dhAbove = 4,            -- niveles por encima que aún "renta"
    dhMaxLevel = 59,        -- a partir de 60 se desactiva el ayudante
    eventRanks = { [0] = true, [1] = true },  -- rangos de guild que pueden crear eventos
    eventNames = {},        -- mains con permiso a dedo: [nombre] = true
}

function SG:Cfg()
    local gdb = self:GuildDB()
    if not gdb then return self:CopyDefaults({}, S.defaults) end
    -- los rangos con permiso son una tabla "dispersa": solo se copian si no existen
    local hadRanks = gdb.settings.eventRanks ~= nil
    self:CopyDefaults(gdb.settings, S.defaults)
    if not hadRanks then gdb.settings.eventRanks = { [0] = true, [1] = true } end
    return gdb.settings
end

function SG:Feature(name)
    local f = self:Cfg().features
    return f[name] ~= false
end

-- ¿Este personaje es el GM o un alter de la cuenta del GM?
function SG:IsAdmin(name)
    name = self:Short(name or self:MyName())
    if self.gmName and name == self.gmName then return true end
    local gdb = self:GuildDB()
    if not gdb then return false end
    if name == self:MyName() then
        return gdb.gmAccount ~= nil and gdb.gmAccount == self.db.accountId
            or self.db.my.isGMAccount[self:GuildName() or ""] == true
    end
    local acc = gdb.gmAccount and gdb.accounts[gdb.gmAccount]
    return acc ~= nil and acc.chars ~= nil and acc.chars[name] ~= nil
end

function SG:CanCreateEvents(name)
    name = self:Short(name or self:MyName())
    if self:IsAdmin(name) then return true end
    local cfg = self:Cfg()
    local r = self.roster[name]
    if r and cfg.eventRanks[r.rankIndex] then return true end
    local main = self:MainOf(name)
    if cfg.eventNames[main] or cfg.eventNames[name] then return true end
    return false
end

function S:Publish()
    if not SG:IsAdmin() then
        SG:Print("Solo el GM (o sus alters) puede cambiar los ajustes.")
        return
    end
    local cfg = SG:Cfg()
    cfg.ver = SG:Now()
    cfg.by = SG:MyName()
    Comm:Send({ t = "SETTINGS", s = cfg }, "GUILD")
    SG:Print("Ajustes guardados y enviados a la guild.")
    SG:Fire("SETTINGS_CHANGED")
end

local function accept(s)
    local gdb = SG:GuildDB()
    if not gdb or type(s) ~= "table" then return end
    if (s.ver or 0) <= (gdb.settings.ver or 0) then return end
    if not SG:IsAdmin(s.by) then return end
    gdb.settings = s
    SG:Fire("SETTINGS_CHANGED")
end

Comm:Register("SETTINGS", function(msg, sender)
    -- directo del admin, o reenviado por otro (validamos el autor original)
    if msg.s and (SG:IsAdmin(sender) or SG:IsAdmin(msg.s.by)) then accept(msg.s) end
end)

-- Si alguien llega con ajustes antiguos, el relay le pasa los nuevos
SG:Listen("HELLO_RELAY", function(hello, sender)
    local cfg = SG:Cfg()
    if (cfg.ver or 0) > (hello.sv or 0) then
        Comm:Send({ t = "SETTINGS", s = cfg }, "WHISPER", sender)
    end
end)
SG:Listen("HELLO_RECEIVED", function(hello, sender)
    -- el admin siempre responde aunque no sea relay
    if SG:IsAdmin() then
        local cfg = SG:Cfg()
        if (cfg.ver or 0) > (hello.sv or 0) then
            C_Timer.After(2, function() Comm:Send({ t = "SETTINGS", s = cfg }, "WHISPER", sender) end)
        end
    end
end)
