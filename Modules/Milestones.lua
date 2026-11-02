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

-- Comprueba un valor contra una lista de hitos y lanza las cartas pendientes.
-- key: prefijo único ("pvp", "goldE", "goldH", "dung"). formatCount: fn(at) -> texto
function M:Check(key, list, value, kicker, vars, formatCount)
    local done = SG.db.my.milestones
    for i, r in ipairs(list) do
        local k = key .. ":" .. r.at
        if value >= r.at and not done[k] then
            done[k] = SG:Now()
            local v = {}
            for a, b in pairs(vars or {}) do v[a] = b end
            v.count = formatCount and formatCount(value) or value
            SG.Popup:Card({
                kicker = kicker,
                icon = r.icon,
                title = SG:Fmt(r.title, v),
                rank = SG:Fmt(r.name, v),
                text = SG:Fmt(r.text, v),
            })
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
