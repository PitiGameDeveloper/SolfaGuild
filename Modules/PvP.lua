-- SolfaGuild - PvP de mundo abierto
-- Cuenta un asesinato cuando muere un jugador enemigo al que tú (o tu mascota)
-- has dañado en los últimos 20 s, o al que has dado el golpe de gracia.
-- Solo fuera de instancias (ni campos de batalla ni mazmorras).
--
-- Asesinatos coordinados: si otros miembros de la guild también dañaron a ese
-- enemigo en esos 20 s (no hace falta ir en grupo), se apunta el "equipo"
-- (nombres de personaje ordenados). En la ventana se agrupa por cuenta, así
-- que cuenta igual aunque vayan con alters y sigue al main que tenga cada uno.

local _, ns = ...
local SG = ns.SG

local PvP = SG:RegisterModule("PvP", {})
SG.PvP = PvP

local band = bit.band
local TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
local HOSTILE     = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40
local MINE        = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x1

local WINDOW = 20
local recent = {}     -- [destGUID] = { t = GetTime() de mi último daño, helpers = { [nombre] = GetTime() } }
local counted = {}    -- [destGUID] = GetTime() (evita contar doble UNIT_DIED + PARTY_KILL)

local function isEnemyPlayer(flags)
    return band(flags, TYPE_PLAYER) > 0 and band(flags, HOSTILE) > 0
end

local function isFriendlyPlayer(flags)
    return band(flags, TYPE_PLAYER) > 0 and band(flags, HOSTILE) == 0 and band(flags, MINE) == 0
end

local function inOpenWorld()
    local inInstance = IsInInstance()
    return not inInstance
end

-- Equipo del asesinato: yo + compañeros de guild que dañaron al enemigo a tiempo
local function teamKey(info)
    local now, me = GetTime(), SG:MyName()
    local names = { me }
    for name, t in pairs(info and info.helpers or {}) do
        if name ~= me and now - t <= WINDOW and SG:IsGuildMember(name) then names[#names + 1] = name end
    end
    if #names < 2 then return nil end
    table.sort(names)
    return table.concat(names, ",")
end

local function registerKill(destGUID, destName)
    local now = GetTime()
    if counted[destGUID] and now - counted[destGUID] < 60 then return end
    counted[destGUID] = now
    local info = recent[destGUID]
    recent[destGUID] = nil

    local c = SG:MyChar()
    SG:CheckWeek(c)
    c.kills = (c.kills or 0) + 1
    c.killsWeek = (c.killsWeek or 0) + 1
    local zone = GetRealZoneText() or GetZoneText() or "?"
    c.zones[zone] = (c.zones[zone] or 0) + 1
    c.zonesWeek[zone] = (c.zonesWeek[zone] or 0) + 1
    local team = teamKey(info)
    if team then
        c.teams[team] = (c.teams[team] or 0) + 1
        c.teamsWeek[team] = (c.teamsWeek[team] or 0) + 1
    end
    SG:MarkDirty()
    SG:Debug("Asesinato PvP:", destName or "?", "en", zone, team and ("equipo " .. team) or "")
    SG:Fire("PVP_KILL", destName, zone)

    local total = SG.Milestones:MyTotals().kills
    SG.Milestones:Check("pvp", SG.Texts.pvpRanks, total, "RANGO PVP DESBLOQUEADO", { zone = zone })
end

SG:On("COMBAT_LOG_EVENT_UNFILTERED", function()
    if not SG:Feature("pvp") then return end
    local _, sub, _, srcGUID, srcName, srcFlags, _, destGUID, destName, destFlags = CombatLogGetCurrentEventInfo()
    if not destFlags then return end

    if sub == "UNIT_DIED" then
        if recent[destGUID] and GetTime() - recent[destGUID].t <= WINDOW
            and isEnemyPlayer(destFlags) and inOpenWorld() then
            registerKill(destGUID, destName)
        end
        return
    end

    if sub == "PARTY_KILL" then
        if isEnemyPlayer(destFlags) and inOpenWorld() then
            local mine = band(srcFlags or 0, MINE) > 0
            local r = recent[destGUID]
            if mine or (r and GetTime() - r.t <= WINDOW) then
                if r and srcName and isFriendlyPlayer(srcFlags or 0) then
                    r.helpers[SG:Short(srcName)] = GetTime()
                end
                registerKill(destGUID, destName)
            end
        end
        return
    end

    if sub:sub(-7) == "_DAMAGE" and isEnemyPlayer(destFlags) then
        local f = srcFlags or 0
        if band(f, MINE) > 0 then
            local r = recent[destGUID] or { helpers = {} }
            r.t = GetTime()
            recent[destGUID] = r
        elseif isFriendlyPlayer(f) and srcName then
            -- cualquier jugador aliado (vaya o no en mi grupo); al contar se filtra por guild
            local r = recent[destGUID]
            if not r then r = { t = 0, helpers = {} }; recent[destGUID] = r end
            r.helpers[SG:Short(srcName)] = GetTime()
        end
    end
end)

C_Timer.NewTicker(30, function()
    local now = GetTime()
    for g, r in pairs(recent) do
        local last = r.t
        for _, t in pairs(r.helpers) do if t > last then last = t end end
        if now - last > 120 then recent[g] = nil end
    end
    for g, t in pairs(counted) do if now - t > 120 then counted[g] = nil end end
end)

---------------------------------------------------------------------------
-- Estadísticas de guild (week = true: solo esta semana)
---------------------------------------------------------------------------
local function charField(c, field, week)
    if not week then return c[field] end
    if c.weekKey ~= SG:WeekKey() then return nil end
    return c[field .. "Week"]
end

-- Zonas con al menos un asesinato (sumando a toda la guild), de más a menos
function PvP:Zones(week)
    local zones = {}
    for _, acc in pairs(SG:Accounts()) do
        for _, c in pairs(acc.chars) do
            for z, k in pairs(charField(c, "zones", week) or {}) do zones[z] = (zones[z] or 0) + k end
        end
    end
    local arr = {}
    for z, k in pairs(zones) do
        if k > 0 then arr[#arr + 1] = { zone = z, kills = k } end
    end
    table.sort(arr, function(a, b)
        if a.kills ~= b.kills then return a.kills > b.kills end
        return a.zone < b.zone
    end)
    return arr
end

-- Asesinatos coordinados: equipos de 2 o más cuentas, de más a menos kills.
-- Cada participante apunta el mismo asesinato, así que por equipo se toma el
-- mayor de lo que dice cada uno (no se suman).
function PvP:Teams(week)
    local accounts = SG:Accounts()
    local charToAcc = {}
    for id, acc in pairs(accounts) do
        for name in pairs(acc.chars) do charToAcc[name] = id end
    end
    local best = {}   -- [clave de cuentas] = { ids, kills }
    for _, acc in pairs(accounts) do
        local mine = {}   -- lo que dice esta cuenta, agrupado por equipo de cuentas
        for _, c in pairs(acc.chars) do
            for key, k in pairs(charField(c, "teams", week) or {}) do
                local ids, seen = {}, {}
                for name in key:gmatch("[^,]+") do
                    local id = charToAcc[name]
                    if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
                end
                if #ids >= 2 then
                    table.sort(ids)
                    local akey = table.concat(ids, ",")
                    mine[akey] = mine[akey] or { ids = ids, kills = 0 }
                    mine[akey].kills = mine[akey].kills + k
                end
            end
        end
        for akey, t in pairs(mine) do
            if not best[akey] or t.kills > best[akey].kills then best[akey] = t end
        end
    end
    local arr = {}
    for _, t in pairs(best) do
        local accs = {}
        for _, id in ipairs(t.ids) do accs[#accs + 1] = accounts[id] end
        table.sort(accs, function(a, b) return a.main < b.main end)
        arr[#arr + 1] = { accs = accs, kills = t.kills }
    end
    table.sort(arr, function(a, b) return a.kills > b.kills end)
    return arr
end

-- Escalafón: los jugadores con asesinatos llenan los rangos de Texts.pvpLadder
-- en orden. Devuelve { { name, members = { {acc, value} } } } solo con rangos
-- ocupados, y aparte tu cuenta si aún no tiene asesinatos.
function PvP:Ladder(week)
    local list = SG:Ranking(function(a) return week and SG:AccountWeekKills(a) or SG:AccountSum(a, "kills") end)
    local out, idx = {}, 1
    for _, tier in ipairs(SG.Texts.pvpLadder) do
        local members = {}
        while list[idx] and list[idx].value > 0 and (not tier.players or #members < tier.players) do
            members[#members + 1] = list[idx]
            idx = idx + 1
        end
        if #members > 0 then out[#out + 1] = { name = SG:Fmt(tier.name), members = members } end
    end
    local nobody
    for i = idx, #list do
        if list[i].acc.mine then nobody = list[i] end
    end
    return out, nobody
end

-- Rango del escalafón de una cuenta (nil = sin asesinatos)
function PvP:LadderRankOf(acc, week)
    for _, tier in ipairs(self:Ladder(week)) do
        for _, it in ipairs(tier.members) do
            if it.acc.id == acc.id then return tier.name end
        end
    end
end
