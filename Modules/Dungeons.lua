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
    SG:MarkDirty()
    SG:Print("Mazmorra completada: |cffffd100" .. d.name .. "|r")
    SG:Fire("DUNGEON_DONE", d)
    if not SG:Feature("dungeons") then return end
    local total = SG.Milestones:MyTotals().dungeons
    SG.Milestones:Check("dung", SG.Texts.dungeonRanks, total, "HITO DE MAZMORRAS", { dungeon = d.name })
end

SG:On("COMBAT_LOG_EVENT_UNFILTERED", function()
    local _, sub, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if sub ~= "UNIT_DIED" then return end
    local id = npcId(destGUID)
    local d = id and SG.DungeonByBoss[id]
    if not d then return end
    local inInstance, kind = IsInInstance()
    if inInstance and (kind == "party" or kind == "raid") then D:Complete(d) end
end)

-- ¿Ha completado este personaje la mazmorra? (nil = desconocido / sin addon)
function D:CharDone(charName, dungeonId)
    local acc = SG:AccountOf(charName)
    if not acc then return nil end
    local c = acc.chars[charName]
    if not c or c.manual then return nil end
    return (c.dungeons and c.dungeons[dungeonId] or 0) > 0
end
