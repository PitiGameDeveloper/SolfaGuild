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

-- Nombre de guild de un compañero de grupo. El juego a veces da solo el nombre, sin apellido.
local function guildNameOf(unit)
    local name = SG:UnitFull(unit)
    if not name then return nil end
    if SG:IsGuildMember(name) then return SG:Short(name) end
    if name:find(" ", 1, true) then return nil end
    local prefix = name .. " "
    for full in pairs(SG.roster) do
        if full:sub(1, #prefix) == prefix then return full end
    end
end

-- Solfamidas de mi grupo (yo incluido), ordenados; nil si no voy con ninguno
local function groupKey()
    if not IsInGroup() then return nil end
    local me, raid = SG:MyName(), IsInRaid()
    local names, seen = { me }, { [me] = true }
    for i = 1, GetNumGroupMembers() do
        local unit = raid and ("raid" .. i) or ("party" .. i)
        local name = UnitExists(unit) and guildNameOf(unit)
        if name and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    if #names < 2 then return nil end
    table.sort(names)
    return table.concat(names, ",")
end

function D:Complete(d)
    local now = GetTime()
    if lastDone[d.id] and now - lastDone[d.id] < 3600 then return end
    lastDone[d.id] = now
    local c = SG:MyChar()
    c.dungeons[d.id] = (c.dungeons[d.id] or 0) + 1
    SG:CheckWeek(c)
    c.dungeonsWeek = (c.dungeonsWeek or 0) + 1
    c.dgWeek[d.id] = (c.dgWeek[d.id] or 0) + 1
    local group = groupKey()
    if group then
        local key = d.id .. "|" .. group
        c.dgTeams[key] = (c.dgTeams[key] or 0) + 1
        c.dgTeamsWeek[key] = (c.dgTeamsWeek[key] or 0) + 1
    end
    SG:MarkDirty()
    SG:Fire("DUNGEON_DONE", d)
end

-- Al llegar al nivel de la primera mazmorra se avisa una vez por cuenta: un alter
-- de quien ya ha subido a otro por encima no estrena nada.
SG:On("PLAYER_LEVEL_UP", function(level)
    if SG.restoring or not SG:Feature("dungeons") then return end
    local done = SG.db.my.milestones
    if done.firstDungeon then return end
    local first, names = math.huge, {}
    for _, d in ipairs(SG.Dungeons) do
        if d.min < first then first, names = d.min, { d.name }
        elseif d.min == first then names[#names + 1] = d.name end
    end
    if level ~= first then return end
    for _, c in pairs(SG.db.my.chars) do
        if (tonumber(c.level) or 0) > level then return end
    end
    done.firstDungeon = SG:Now()
    SG.Milestones:ShowCard(SG.Texts.firstDungeon, "LOS SOLFAMIDAS", { level = level, dungeon = table.concat(names, " o ") })
    SG:MarkDirty()
end)

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

-- Completaciones de toda la guild (week = true: solo esta semana). Quienes van juntos
-- apuntan la misma, así que de cada grupo se toma el mayor de lo que dice cada uno (no se
-- suman); lo que cada personaje hizo sin Solfamidas en su grupo se suma tal cual.
-- Devuelve las mazmorras { { name, runs } } y los grupos { { accs, runs } }, de más a menos.
function D:Runs(week)
    local accounts = SG:Accounts()
    local wk = week and SG:WeekKey()
    local charToAcc = {}
    for id, acc in pairs(accounts) do
        for name in pairs(acc.chars) do charToAcc[name] = id end
    end
    local counts, best = {}, {}   -- [mazmorra] = completaciones; ["mazmorra|cuentas"] = { d, ids, runs }
    for _, acc in pairs(accounts) do
        local mine = {}   -- lo que dice esta cuenta, agrupado por mazmorra y cuentas
        for _, c in pairs(acc.chars) do
            if not week or c.weekKey == wk then
                local together = {}   -- [mazmorra] = veces que este personaje iba en grupo
                for key, n in pairs((week and c.dgTeamsWeek or c.dgTeams) or {}) do
                    local d, group = key:match("^([^|]+)|(.+)$")
                    if d then
                        together[d] = (together[d] or 0) + n
                        local ids, seen = {}, {}
                        for name in group:gmatch("[^,]+") do
                            local id = charToAcc[name]
                            if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
                        end
                        table.sort(ids)
                        local akey = d .. "|" .. table.concat(ids, ",")
                        mine[akey] = mine[akey] or { d = d, ids = ids, runs = 0 }
                        mine[akey].runs = mine[akey].runs + n
                    end
                end
                for d, n in pairs((week and c.dgWeek or c.dungeons) or {}) do
                    local alone = n - (together[d] or 0)
                    if alone > 0 then counts[d] = (counts[d] or 0) + alone end
                end
            end
        end
        for akey, t in pairs(mine) do
            if not best[akey] or t.runs > best[akey].runs then best[akey] = t end
        end
    end
    local groups = {}   -- [cuentas] = { ids, runs }
    for _, t in pairs(best) do
        counts[t.d] = (counts[t.d] or 0) + t.runs
        if #t.ids >= 2 then
            local key = table.concat(t.ids, ",")
            groups[key] = groups[key] or { ids = t.ids, runs = 0 }
            groups[key].runs = groups[key].runs + t.runs
        end
    end
    local dungeons = {}
    for id, runs in pairs(counts) do
        local d = SG.DungeonById[id]
        if d then dungeons[#dungeons + 1] = { name = d.name, runs = runs } end
    end
    table.sort(dungeons, function(a, b)
        if a.runs ~= b.runs then return a.runs > b.runs end
        return a.name < b.name
    end)
    local arr = {}
    for _, g in pairs(groups) do
        local accs = {}
        for _, id in ipairs(g.ids) do accs[#accs + 1] = accounts[id] end
        table.sort(accs, function(a, b) return a.main < b.main end)
        arr[#arr + 1] = { accs = accs, runs = g.runs }
    end
    table.sort(arr, function(a, b)
        if a.runs ~= b.runs then return a.runs > b.runs end
        return a.accs[1].main < b.accs[1].main
    end)
    return dungeons, arr
end

-- Escalafón de mazmorras, igual que el de PvP (ver Texts.pveLadder)
function D:Ladder(week)
    local list = SG:Ranking(function(a) return week and SG:AccountWeekDungeons(a) or SG:AccountDungeons(a) end)
    return SG:BuildLadder(list, SG.Texts.pveLadder)
end

function D:LadderRankOf(acc, week)
    return SG:LadderRankOf(self:Ladder(week), acc)
end
