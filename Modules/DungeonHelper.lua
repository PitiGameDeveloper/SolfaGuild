-- SolfaGuild - Ayudante de mazmorras
-- Al llegar al nivel en que tienes desbloqueadas las misiones de una mazmorra,
-- te avisa, te lista las misiones (waypoints con TomTom si hay coordenadas) y te
-- dice qué compañeros de guild están en rango y no la han hecho, para susurrarles.
-- Se desactiva al nivel configurado por el GM (por defecto 59+).

local _, ns = ...
local SG = ns.SG

local DH = SG:RegisterModule("DungeonHelper", {})
SG.DungeonHelper = DH

local function key(d) return SG:MyName() .. ":" .. d.id end

function DH:LevelRange(d)
    local cfg = SG:Cfg()
    return d.unlock - (cfg.dhBelow or 2), d.unlock + (cfg.dhAbove or 4)
end

-- Compañeros en rango para una mazmorra
function DH:Candidates(d)
    local lo, hi = self:LevelRange(d)
    local out = {}
    local me = SG:MyName()
    for name, r in pairs(SG.roster) do
        if name ~= me and r.level >= lo and r.level <= hi then
            local done = SG.DungeonTracker:CharDone(name, d.id)
            if done ~= true then
                out[#out + 1] = { name = name, level = r.level, class = r.class, online = r.online,
                    unknown = done == nil, main = SG:MainOf(name) }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.online ~= b.online then return a.online end
        return a.name < b.name
    end)
    return out
end

function DH:AddWaypoints(d)
    local n = 0
    if TomTom and TomTom.AddWaypoint then
        for _, q in ipairs(d.quests or {}) do
            if q.map and q.x and q.y then
                TomTom:AddWaypoint(q.map, q.x / 100, q.y / 100, { title = q.name, persistent = false })
                n = n + 1
            end
        end
    end
    return n
end

function DH:ShowCandidates(d)
    local rows = {}
    for _, c in ipairs(self:Candidates(d)) do
        local label = SG:ClassColor(c.class) .. c.name .. "|r (" .. c.level .. ")"
        if c.main ~= c.name then label = label .. " |cff999999alter de " .. c.main .. "|r" end
        if c.unknown then label = label .. " |cff888888[sin datos]|r" end
        if not c.online then label = label .. " |cff666666- desconectado|r" end
        rows[#rows + 1] = { label = label, value = c.name, checked = c.online, disabled = not c.online }
    end
    local lo, hi = self:LevelRange(d)
    SG.Popup:PickList({
        title = SG:Fmt(SG.Texts.ui.dhTitle, { dungeon = d.name }),
        text = (#rows > 0)
            and ("Solfamidas entre nivel " .. lo .. " y " .. hi .. " que no la han completado. Marca a quién susurrar:")
            or "Ahora mismo no hay nadie de la guild en rango para esta mazmorra.",
        rows = rows,
        button = "Susurrar",
        onAccept = function(sel)
            local msg = SG:Fmt(SG.Texts.ui.dhWhisper, { dungeon = d.name })
            for _, name in ipairs(sel) do SendChatMessage(msg, "WHISPER", nil, name) end
            if #sel > 0 then SG:Print("Susurrado a " .. #sel .. " compañero(s).") end
        end,
    })
end

function DH:Announce(d)
    local lines = {}
    for _, q in ipairs(d.quests or {}) do
        lines[#lines + 1] = "- |cffffd100" .. q.name .. "|r" .. (q.giver and (" - " .. q.giver) or "")
    end
    local questText = #lines > 0 and table.concat(lines, "\n") or "|cff999999(Misiones aún sin definir para esta mazmorra)|r"
    SG.Popup:Card({
        kicker = "MAZMORRA DISPONIBLE",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        title = d.name,
        rank = "Nivel " .. d.min .. " - " .. d.max,
        text = "Ya tienes nivel para sus misiones:\n\n" .. questText,
        button = "Ver compañeros",
        onClose = function()
            local n = DH:AddWaypoints(d)
            if n > 0 then SG:Print(n .. " waypoints añadidos en TomTom.") end
            DH:ShowCandidates(d)
        end,
    })
end

-- Mazmorras que "tocan" para un nivel
function DH:ForLevel(level)
    local out = {}
    local cfg = SG:Cfg()
    for _, d in ipairs(SG.Dungeons) do
        if level >= d.unlock and level <= d.unlock + (cfg.dhAbove or 4) then out[#out + 1] = d end
    end
    return out
end

function DH:Check(level, silentOld)
    if not SG:Feature("dungeonHelper") then return end
    local cfg = SG:Cfg()
    if level > (cfg.dhMaxLevel or 59) then return end
    local notified = SG.db.my.dhNotified
    for _, d in ipairs(SG.Dungeons) do
        local k = key(d)
        if not notified[k] then
            if level > d.unlock + (cfg.dhAbove or 4) then
                if silentOld then notified[k] = true end   -- ya te la pasaste de nivel
            elseif level >= d.unlock and not SG.DungeonTracker:CharDone(SG:MyName(), d.id) then
                notified[k] = true
                DH:Announce(d)
            end
        end
    end
end

function DH:OnLogin()
    C_Timer.After(20, function() DH:Check(UnitLevel("player"), true) end)
end

SG:On("PLAYER_LEVEL_UP", function(level)
    -- esperamos un poco para que el roster se actualice
    C_Timer.After(3, function() SG:RequestRoster() end)
    C_Timer.After(6, function() DH:Check(level, false) end)
end)
