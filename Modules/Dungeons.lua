-- SolfaGuild - Mazmorras completadas (muerte del jefe final dentro de la instancia)

local _, ns = ...
local SG = ns.SG

local D = SG:RegisterModule("DungeonTracker", {})
SG.DungeonTracker = D

local lastDone = {}   -- [dungeonId] = GetTime() (evita contar dos veces el mismo run)

local function npcId(guid)
    if not guid then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

function D:Complete(d)
    local now = GetTime()
    if lastDone[d.id] and now - lastDone[d.id] < 3600 then return end
    lastDone[d.id] = now
    local c = SG:MyChar()
    c.dungeons[d.id] = (c.dungeons[d.id] or 0) + 1
    SG:CheckWeek(c)
    c.dungeonsWeek = (c.dungeonsWeek or 0) + 1
    SG:MarkDirty()
    SG:Print("Mazmorra completada: |cffffd100" .. d.name .. "|r")
    SG:Fire("DUNGEON_DONE", d)
    if not SG:Feature("dungeons") then return end
    local total = SG.Milestones:MyTotals().dungeons
    SG.Milestones:Check("dung", SG.Texts.dungeonRanks, total, "HITO DE MAZMORRAS", { dungeon = d.name })
end

local function onDeath(guid)
    -- en Forever algunos valores pueden venir ocultos: con esos no se puede operar
    if not guid or (issecretvalue and issecretvalue(guid)) then return end
    local id = npcId(guid)
    local d = id and SG.DungeonByBoss[id]
    if d then SG:Try(D.Complete, D, d) end
end

-- Solo se escucha dentro de mazmorras y bandas (fuera no hay jefes que contar), y
-- lo único que se mira es si alguien ha muerto. En Forever no hay registro de
-- combate: están los eventos UNIT_DIED y PARTY_KILL. Complete() ya evita contar dos veces.
local DEATH_EVENTS = SG.HasCombatLog and { "COMBAT_LOG_EVENT_UNFILTERED" } or { "UNIT_DIED", "PARTY_KILL" }
local cl = CreateFrame("Frame")
cl:SetScript("OnEvent", function(_, event, a, b)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, sub, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
        if sub == "UNIT_DIED" then onDeath(destGUID) end
    elseif event == "UNIT_DIED" then
        onDeath(a)
    else
        onDeath(b)
    end
end)

local function updateListening()
    local inInstance, kind = IsInInstance()
    local inside = inInstance and (kind == "party" or kind == "raid")
    for _, event in ipairs(DEATH_EVENTS) do
        if inside then cl:RegisterEvent(event) else cl:UnregisterEvent(event) end
    end
end
SG:On("PLAYER_ENTERING_WORLD", updateListening)
SG:On("ZONE_CHANGED_NEW_AREA", updateListening)

-- ¿Ha completado este personaje la mazmorra? (nil = desconocido / sin addon)
function D:CharDone(charName, dungeonId)
    local acc = SG:AccountOf(charName)
    if not acc then return nil end
    local c = acc.chars[charName]
    if not c then return nil end
    return (c.dungeons and c.dungeons[dungeonId] or 0) > 0
end

-- Escalafón de mazmorras, igual que el de PvP (ver Texts.pveLadder)
function D:Ladder(week)
    local list = SG:Ranking(function(a) return week and SG:AccountWeekDungeons(a) or SG:AccountDungeons(a) end)
    return SG:BuildLadder(list, SG.Texts.pveLadder)
end

function D:LadderRankOf(acc, week)
    return SG:LadderRankOf(self:Ladder(week), acc)
end
