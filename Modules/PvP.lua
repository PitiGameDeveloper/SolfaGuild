-- SolfaGuild - PvP de mundo abierto
-- Cuenta un asesinato cuando muere un jugador enemigo al que tú (o tu mascota)
-- has dañado en los últimos 20 s, o al que has dado el golpe de gracia.
-- Solo fuera de instancias (ni campos de batalla ni mazmorras).
--
-- Asesinatos coordinados: si otros miembros de la guild también dañaron a ese
-- enemigo en esos 20 s (no hace falta ir en grupo), se apunta el "equipo"
-- (nombres de personaje ordenados). En la ventana se agrupa por cuenta, así
-- que cuenta igual aunque vayan con alters y sigue al main que tenga cada uno.
--
-- En Forever no hay registro de combate (ver la sección "Forever"):
-- - Un asesinato es una muerte honorable: el juego decide si cuenta o no. Un enemigo
--   que no da honor (por ejemplo, gris para un nivel 60) no cuenta para ese jugador.
-- - Asesinato coordinado: quien consigue una muerte honorable avisa a la guild con
--   el identificador (GUID) del muerto, y si otros han avisado del mismo sois equipo.
--   El aviso de honor no dice quién era: sale de los eventos UNIT_DIED y PARTY_KILL.
--   Si alguno no lo tiene: misma zona, casi a la vez, y mismo grupo o mismo objetivo.

local _, ns = ...
local SG = ns.SG

local Comm = SG.Comm

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

local function addTeam(team)
    local c = SG:MyChar()
    SG:CheckWeek(c)
    c.teams[team] = (c.teams[team] or 0) + 1
    c.teamsWeek[team] = (c.teamsWeek[team] or 0) + 1
end

local function addKill(destName, team)
    local c = SG:MyChar()
    SG:CheckWeek(c)
    c.kills = (c.kills or 0) + 1
    c.killsWeek = (c.killsWeek or 0) + 1
    local zone = GetRealZoneText() or GetZoneText() or "?"
    c.zones[zone] = (c.zones[zone] or 0) + 1
    c.zonesWeek[zone] = (c.zonesWeek[zone] or 0) + 1
    if team then addTeam(team) end
    SG:MarkDirty()
    SG:Debug("Asesinato PvP:", destName or "?", "en", zone, team and ("equipo " .. team) or "")
    SG:Fire("PVP_KILL", destName, zone)

    local total = SG.Milestones:MyTotals().kills
    SG.Milestones:Check("pvp", SG.Texts.pvpRanks, total, "RANGO PVP DESBLOQUEADO", { zone = zone })
end

local function registerKill(destGUID, destName)
    local now = GetTime()
    if counted[destGUID] and now - counted[destGUID] < 60 then return end
    counted[destGUID] = now
    local info = recent[destGUID]
    recent[destGUID] = nil
    addKill(destName, teamKey(info))
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
-- Forever: sin registro de combate
---------------------------------------------------------------------------
local TEAM_TIME = 5        -- s de margen para juntar dos muertes sin identificador
local ID_TIME = 15         -- s de margen para juntar dos muertes con el mismo identificador
local TEAM_WAIT = 6        -- s esperando a que los demás digan que también les ha contado
local DEATH_TIME = 6       -- s que una muerte vista puede ser la de una muerte honorable

local lifetimeHK           -- muertes honorables de toda la vida (solo sube)
local othersKilled = {}    -- { { who, t, zone, id, foe } } muertes honorables de los compañeros
local deaths = {}          -- { { id, t, name, mine } } jugadores enemigos muertos sin asignar
local lastFoe, lastFoeAt   -- último jugador enemigo que has tenido de objetivo y hasta cuándo
local targetingFoe = false

-- Facción de las razas que solo pueden ser de un bando. Los Skyborne eligen bando al
-- crear el personaje, así que la raza no dice nada de ellos y no están aquí.
local RACE_FACTION = {
    Human = "Alliance", Dwarf = "Alliance", NightElf = "Alliance", Gnome = "Alliance",
    Orc = "Horde", Scourge = "Horde", Tauren = "Horde", Troll = "Horde",
}

local function targetFoe()
    if not (SG:Open(UnitExists("target")) and SG:Open(UnitIsPlayer("target"))) then return nil end
    local mine, theirs = SG:Open(UnitFactionGroup("player")), SG:Open(UnitFactionGroup("target"))
    if not mine or not theirs or mine == theirs then return nil end
    return SG:UnitFull("target")
end

-- Solo sirve para saber si dos muertes honorables son la misma; nunca suma asesinatos
local function currentFoe()
    local foe = targetFoe()
    if foe then return foe end
    if lastFoe and GetTime() - lastFoeAt <= WINDOW then return lastFoe end
end

-- ¿Es de mi bando? Lo mejor es preguntárselo al juego, si lo tienes a la vista; si no,
-- por la guild o por la raza. Si no se sabe (un Skyborne lejos), se da por enemigo:
-- como mucho se asigna mal esta muerte y no sale como equipo, pero la kill cuenta igual.
local function isMySide(guid, name, race)
    local mine = SG:Open(UnitFactionGroup("player"))
    local unit = UnitTokenFromGUID and SG:Open(UnitTokenFromGUID(guid))
    local theirs = unit and SG:Open(UnitFactionGroup(unit))
    if theirs then return theirs == mine end
    if name and SG.roster[name] then return true end
    local faction = race and RACE_FACTION[race]
    return faction ~= nil and faction == mine
end

-- Muere alguien cerca: lo que no sea un jugador se descarta lo primero
local function onDeathSeen(guid, mine)
    guid = SG:Open(guid)
    if type(guid) ~= "string" or not guid:find("^Player%-") then return end
    local _, _, _, race, _, name = GetPlayerInfoByGUID(guid)
    race, name = SG:Open(race), SG:Open(name)
    name = name and SG:Short(name)
    if isMySide(guid, name, race) then return end
    local now = GetTime()
    for _, d in ipairs(deaths) do
        if d.id == guid and now - d.t <= DEATH_TIME then   -- llega por los dos eventos
            d.mine = d.mine or mine
            return
        end
    end
    deaths[#deaths + 1] = { id = guid, t = now, name = name, mine = mine }
end

-- ¿Quién era el muerto de esta muerte honorable? Primero el que ha matado tu grupo,
-- luego tu enemigo y, si no, el que lleva más tiempo sin asignar.
local function takeDeath(foe)
    local now = GetTime()
    for i = #deaths, 1, -1 do
        if now - deaths[i].t > DEATH_TIME then table.remove(deaths, i) end
    end
    local best
    for i, d in ipairs(deaths) do
        if d.mine then best = i; break end
    end
    if not best and foe then
        for i, d in ipairs(deaths) do
            if d.name == foe then best = i; break end
        end
    end
    best = best or (deaths[1] and 1)
    if best then return table.remove(deaths, best).id end
end

-- ¿Es la misma muerte? Con identificador en los dos, se mira solo eso.
local function sameKill(k, killedAt, zone, id, foe)
    if id and k.id then return k.id == id and math.abs(k.t - killedAt) <= ID_TIME end
    if k.zone ~= zone or math.abs(k.t - killedAt) > TEAM_TIME then return false end
    return (foe and k.foe == foe) or SG:InMyGroup(k.who)
end

-- Unos segundos después de cada asesinato: ¿a quién más le ha contado esta misma muerte?
local function closeTeam(killedAt, zone, id, foe)
    local names, added = { SG:MyName() }, {}
    for _, k in ipairs(othersKilled) do
        if not added[k.who] and sameKill(k, killedAt, zone, id, foe) then
            added[k.who] = true
            names[#names + 1] = k.who
        end
    end
    if #names >= 2 then
        table.sort(names)
        addTeam(table.concat(names, ","))
    end
end

-- El contador de muertes honorables ha subido
local function onHonorableKill()
    local hk = SG:Open((GetPVPLifetimeStats()))
    if type(hk) ~= "number" then return end
    local gained = lifetimeHK and (hk - lifetimeHK) or 0
    lifetimeHK = hk
    if gained <= 0 or not inOpenWorld() or not SG:Feature("pvp") then return end
    local now = GetTime()
    local zone = GetRealZoneText() or GetZoneText() or "?"
    local foe = currentFoe()
    for _ = 1, gained do
        local id = takeDeath(foe)
        addKill(nil)
        SG:Debug("Muerte honorable. Identificador:", id or "ninguno", "- objetivo:", foe or "ninguno")
        Comm:Send({ t = "PK", z = zone, id = id, foe = foe }, "GUILD")
        C_Timer.After(TEAM_WAIT, function() SG:Try(closeTeam, now, zone, id, foe) end)
    end
end

if not SG.HasCombatLog then
    SG:On("PLAYER_PVP_KILLS_CHANGED", function()
        -- un momento para que el contador ya esté al día
        C_Timer.After(1, function() SG:Try(onHonorableKill) end)
    end)
    SG:On("UNIT_DIED", function(guid) onDeathSeen(guid, false) end)
    SG:On("PARTY_KILL", function(_, guid) onDeathSeen(guid, true) end)
    SG:On("PLAYER_TARGET_CHANGED", function()
        local foe = targetFoe()
        if foe then lastFoe = foe end
        if foe or targetingFoe then lastFoeAt = GetTime() end
        targetingFoe = foe ~= nil
    end)
    SG:On("PLAYER_ENTERING_WORLD", function()
        if not lifetimeHK then lifetimeHK = SG:Open((GetPVPLifetimeStats())) end
    end)
    Comm:Register("PK", function(msg, sender)
        if type(msg.z) ~= "string" or not SG:IsGuildMember(sender) then return end
        local now = GetTime()
        for i = #othersKilled, 1, -1 do
            if now - othersKilled[i].t > 60 then table.remove(othersKilled, i) end
        end
        othersKilled[#othersKilled + 1] = { who = sender, t = now, zone = msg.z, id = msg.id, foe = msg.foe }
    end)
end

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

-- Escalafón (ver Texts.pvpLadder)
function PvP:Ladder(week)
    local list = SG:Ranking(function(a) return week and SG:AccountWeekKills(a) or SG:AccountSum(a, "kills") end)
    return SG:BuildLadder(list, SG.Texts.pvpLadder)
end

-- Rango del escalafón de una cuenta (nil = sin asesinatos)
function PvP:LadderRankOf(acc, week)
    return SG:LadderRankOf(self:Ladder(week), acc)
end
