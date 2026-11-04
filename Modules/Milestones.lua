-- SolfaGuild - Hitos y rangos (comunes a PvP, oro y mazmorras)

local _, ns = ...
local SG = ns.SG

local M = SG:RegisterModule("Milestones", {})
SG.Milestones = M

-- Índice del rango alcanzado para un valor (0 = ninguno)
function M:RankIndex(list, value)
    local idx = 0
    for i, r in ipairs(list) do
        if value >= r.at then idx = i end
    end
    return idx
end

function M:RankName(list, value)
    local i = self:RankIndex(list, value)
    if i == 0 then return "Sin rango" end
    return SG:Fmt(list[i].name)
end

-- Enseña la carta de un hito. Si trae tab, su botón abre esa pestaña del addon.
function M:ShowCard(r, kicker, vars)
    SG.Popup:Card({
        kicker = kicker,
        icon = r.icon,
        title = SG:Fmt(r.title, vars),
        rank = SG:Fmt(r.name, vars),
        text = SG:Fmt(r.text, vars),
        button = r.button,
        onClose = r.tab and function() SG:Try(SG.UI.Show, SG.UI, r.tab) end,
    })
end

-- Comprueba un valor contra una lista de hitos y lanza las cartas pendientes.
-- Los hitos sin title no avisan.
-- key: prefijo único ("pvp", "goldE", "goldH"). formatCount: fn(at) -> texto
function M:Check(key, list, value, kicker, vars, formatCount)
    -- mientras se recuperan los datos de la guild no sabemos qué hitos ya se celebraron
    if SG.restoring then return end
    local done = SG.db.my.milestones
    for i, r in ipairs(list) do
        local k = key .. ":" .. r.at
        if r.title and value >= r.at and not done[k] then
            done[k] = SG:Now()
            local v = {}
            for a, b in pairs(vars or {}) do v[a] = b end
            v.count = formatCount and formatCount(value) or value
            self:ShowCard(r, kicker, v)
            SG:MarkDirty()
        end
    end
end

-- Totales de mi cuenta (todos mis personajes de la guild)
function M:MyTotals()
    local acc = SG:MyAccount()
    return {
        kills = SG:AccountSum(acc, "kills"),
        earned = SG:AccountSum(acc, "earned"),
        dungeons = SG:AccountDungeons(acc),
        killsWeek = SG:AccountWeekKills(acc),
        dungeonsWeek = SG:AccountWeekDungeons(acc),
        played = SG:AccountSum(acc, "played"),
        acc = acc,
    }
end

-- Rangos de una cuenta cualquiera (para filtros de eventos)
function M:PvPRankOf(acc) return self:RankIndex(SG.Texts.pvpRanks, SG:AccountSum(acc, "kills")) end
function M:DungeonRankOf(acc) return self:RankIndex(SG.Texts.dungeonRanks, SG:AccountDungeons(acc)) end
