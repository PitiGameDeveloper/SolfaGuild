-- SolfaGuild - PvP de mundo abierto
-- Cuenta un asesinato cuando muere un jugador enemigo al que tú (o tu mascota)
-- has dañado en los últimos 20 s, o al que has dado el golpe de gracia.
-- Solo fuera de instancias (ni campos de batalla ni mazmorras).

local _, ns = ...
local SG = ns.SG

local PvP = SG:RegisterModule("PvP", {})
SG.PvP = PvP

local band = bit.band
local TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
local HOSTILE     = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40
local MINE        = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x1
local PARTY       = COMBATLOG_OBJECT_AFFILIATION_PARTY or 0x2
local RAID        = COMBATLOG_OBJECT_AFFILIATION_RAID or 0x4

local WINDOW = 20
local recent = {}     -- [destGUID] = { t = GetTime(), helpers = { [name] = true } }
local counted = {}    -- [destGUID] = GetTime() (evita contar doble UNIT_DIED + PARTY_KILL)

local function isEnemyPlayer(flags)
    return band(flags, TYPE_PLAYER) > 0 and band(flags, HOSTILE) > 0
end

local function inOpenWorld()
    local inInstance = IsInInstance()
    return not inInstance
end

local function registerKill(destGUID, destName)
    local now = GetTime()
    if counted[destGUID] and now - counted[destGUID] < 60 then return end
    counted[destGUID] = now
    local info = recent[destGUID]
    recent[destGUID] = nil

    local c = SG:MyChar()
    local wk = SG:WeekKey()
    if c.weekKey ~= wk then c.weekKey = wk; c.killsWeek = 0 end
    c.kills = (c.kills or 0) + 1
    c.killsWeek = (c.killsWeek or 0) + 1
    local zone = GetRealZoneText() or GetZoneText() or "?"
    c.zones[zone] = (c.zones[zone] or 0) + 1
    if info then
        for name in pairs(info.helpers) do
            if name ~= SG:MyName() then c.partners[name] = (c.partners[name] or 0) + 1 end
        end
    end
    SG:MarkDirty()
    SG:Debug("Asesinato PvP:", destName or "?", "en", zone)
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
                if r and srcName and band(srcFlags or 0, PARTY + RAID) > 0 then
                    r.helpers[SG:Short(srcName)] = true
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
        elseif band(f, PARTY + RAID) > 0 and band(f, TYPE_PLAYER) > 0 and srcName then
            local r = recent[destGUID]
            if r then r.helpers[SG:Short(srcName)] = true
            else recent[destGUID] = { t = 0, helpers = { [SG:Short(srcName)] = true } } end
        end
    end
end)

C_Timer.NewTicker(30, function()
    local now = GetTime()
    for g, r in pairs(recent) do if now - r.t > 120 and r.t > 0 then recent[g] = nil end end
    for g, t in pairs(counted) do if now - t > 120 then counted[g] = nil end end
end)

---------------------------------------------------------------------------
-- Estadísticas de guild
---------------------------------------------------------------------------
-- Zona con más muertes (sumando a toda la guild)
function PvP:TopZones(n)
    local zones = {}
    for _, acc in pairs(SG:Accounts()) do
        for _, c in pairs(acc.chars) do
            for z, k in pairs(c.zones or {}) do zones[z] = (zones[z] or 0) + k end
        end
    end
    local arr = {}
    for z, k in pairs(zones) do arr[#arr + 1] = { zone = z, kills = k } end
    table.sort(arr, function(a, b) return a.kills > b.kills end)
    local out = {}
    for i = 1, math.min(n or 5, #arr) do out[i] = arr[i] end
    return out
end

-- Parejas más despiadadas: kills compartidas entre dos jugadores (por main)
function PvP:TopPairs(n)
    local accounts = SG:Accounts()
    local charToMain = {}
    for _, acc in pairs(accounts) do
        for name in pairs(acc.chars) do charToMain[name] = acc.main end
    end
    -- side[a][b] = kills que a dice haber hecho con b
    local side = {}
    for _, acc in pairs(accounts) do
        local a = acc.main
        side[a] = side[a] or {}
        for _, c in pairs(acc.chars) do
            for partner, k in pairs(c.partners or {}) do
                local b = charToMain[partner] or partner
                if a ~= b then side[a][b] = (side[a][b] or 0) + k end
            end
        end
    end
    local seen, arr = {}, {}
    for a, t in pairs(side) do
        for b, k in pairs(t) do
            local x, y = a, b
            if y < x then x, y = y, x end
            local key = x .. "|" .. y
            if not seen[key] then
                -- ambos cuentan la misma kill: se toma el mayor de los dos lados
                local kills = math.max(k, (side[b] and side[b][a]) or 0)
                seen[key] = true
                arr[#arr + 1] = { an = x, bn = y, kills = kills }
            end
        end
    end
    table.sort(arr, function(p1, p2) return p1.kills > p2.kills end)
    local out = {}
    for i = 1, math.min(n or 5, #arr) do out[i] = arr[i] end
    return out
end
