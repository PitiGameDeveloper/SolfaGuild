-- SolfaGuild - Eventos de guild con filtros y avisos
-- Pueden crearlos: el GM y sus alters, los rangos de guild marcados y los mains
-- elegidos a dedo por el GM. El evento se propaga por el canal del addon y,
-- opcionalmente, se crea también en el calendario del WoW (evento de guild si es
-- para todos, o evento con invitaciones a quienes cumplan el filtro).

local _, ns = ...
local SG = ns.SG
local Comm = SG.Comm

local Ev = SG:RegisterModule("Events", {})
SG.Events = Ev

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
Ev.CLASSES = CLASSES

function Ev:All()
    local gdb = SG:GuildDB()
    return gdb and gdb.events or {}
end

function Ev:LatestModified()
    local m = 0
    for _, e in pairs(self:All()) do m = math.max(m, e.modified or 0) end
    return m
end

function Ev:Upcoming()
    local now, out = SG:Now(), {}
    for _, e in pairs(self:All()) do
        if not e.deleted and e.start + 3600 > now then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return a.start < b.start end)
    return out
end

---------------------------------------------------------------------------
-- Filtros
---------------------------------------------------------------------------
-- Comprueba si un personaje (y su cuenta) cumple el filtro
function Ev:Matches(e, charName, level, class, rankIndex, acc)
    local f = e.filter or {}
    if f.maxGuildRank and rankIndex and rankIndex > f.maxGuildRank then return false end
    if f.minLevel and level and level < f.minLevel then return false end
    if f.maxLevel and level and level > f.maxLevel then return false end
    if f.classes and next(f.classes) and class and not f.classes[class] then return false end
    if (f.minPvp and f.minPvp > 0) or (f.minDung and f.minDung > 0) then
        if not acc then return false end
        if f.minPvp and SG.Milestones:PvPRankOf(acc) < f.minPvp then return false end
        if f.minDung and SG.Milestones:DungeonRankOf(acc) < f.minDung then return false end
    end
    return true
end

function Ev:MatchesMe(e)
    return self:Matches(e, SG:MyName(), UnitLevel("player"), select(2, UnitClass("player")),
        SG:MyRankIndex(), SG:MyAccount())
end

function Ev:IsForEveryone(e)
    local f = e.filter or {}
    return not (f.maxGuildRank or f.minLevel or f.maxLevel or (f.classes and next(f.classes))
        or (f.minPvp and f.minPvp > 0) or (f.minDung and f.minDung > 0))
end

function Ev:FilterText(e)
    local f, parts = e.filter or {}, {}
    if self:IsForEveryone(e) then return "Para toda la guild" end
    if f.maxGuildRank then
        local rn = GuildControlGetRankName and GuildControlGetRankName(f.maxGuildRank + 1) or tostring(f.maxGuildRank)
        parts[#parts + 1] = "rango guild hasta " .. (rn or f.maxGuildRank)
    end
    if f.minLevel or f.maxLevel then parts[#parts + 1] = "nivel " .. (f.minLevel or 1) .. "-" .. (f.maxLevel or 60) end
    if f.minPvp and f.minPvp > 0 then parts[#parts + 1] = "PvP: " .. SG:Fmt(SG.Texts.pvpRanks[f.minPvp].name) .. "+" end
    if f.minDung and f.minDung > 0 then parts[#parts + 1] = "Mazmorras: " .. SG.Texts.dungeonRanks[f.minDung].name .. "+" end
    if f.classes and next(f.classes) then
        local cl = {}
        for c in pairs(f.classes) do cl[#cl + 1] = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]) or c end
        parts[#parts + 1] = table.concat(cl, "/")
    end
    return table.concat(parts, ", ")
end

-- Personajes de la guild que cumplen el filtro (para invitaciones de calendario)
function Ev:MatchingRoster(e)
    local out = {}
    for name, r in pairs(SG.roster) do
        if self:Matches(e, name, r.level, r.class, r.rankIndex, SG:AccountOf(name)) then out[#out + 1] = name end
    end
    table.sort(out)
    return out
end

---------------------------------------------------------------------------
-- Crear / borrar / sincronizar
---------------------------------------------------------------------------
local function store(e)
    local gdb = SG:GuildDB()
    if not gdb or type(e) ~= "table" or not e.id then return false end
    local old = gdb.events[e.id]
    if old and (old.modified or 0) >= (e.modified or 0) then return false end
    gdb.events[e.id] = e
    return true
end

function Ev:Create(data, alsoWowCalendar)
    if not SG:CanCreateEvents() then
        SG:Print("No tienes permiso para crear eventos.")
        return
    end
    local now = SG:Now()
    local e = {
        id = SG:MyName() .. "-" .. SG:RandomId(6),
        title = data.title, desc = data.desc, start = data.start,
        filter = data.filter or {}, by = SG:MyName(), byMain = SG.db.my.main,
        created = now, modified = now,
    }
    store(e)
    Comm:Send({ t = "EVENT", e = e }, "GUILD")
    SG:Print("Evento creado: |cffffd100" .. e.title .. "|r (" .. date("%d/%m %H:%M", e.start) .. ")")
    if alsoWowCalendar then self:CreateInWowCalendar(e) end
    SG:Fire("EVENTS_UPDATED")
    return e
end

function Ev:Delete(id)
    local e = self:All()[id]
    if not e then return end
    if e.by ~= SG:MyName() and not SG:IsAdmin() and SG:MainOf(e.by) ~= SG.db.my.main then
        SG:Print("Solo el creador o el GM pueden borrar este evento.")
        return
    end
    e.deleted = true
    e.modified = SG:Now()
    Comm:Send({ t = "EVENT", e = e, del = SG:MyName() }, "GUILD")
    SG:Fire("EVENTS_UPDATED")
end

Comm:Register("EVENT", function(msg, sender)
    local e = msg.e
    if type(e) ~= "table" or not e.by then return end
    if msg.del then
        -- borrado: lo hace el creador (o su cuenta) o un admin
        if not (SG:IsAdmin(msg.del) or msg.del == e.by or SG:MainOf(msg.del) == SG:MainOf(e.by)) then return end
    elseif not SG:CanCreateEvents(e.by) then
        return
    end
    if store(e) then SG:Fire("EVENTS_UPDATED") end
end)

local function sendEventsNewerThan(ts, target)
    for _, e in pairs(Ev:All()) do
        if (e.modified or 0) > (ts or 0) and e.start + 3600 > SG:Now() then
            Comm:Send({ t = "EVENT", e = e, del = e.deleted and e.by or nil }, "WHISPER", target)
        end
    end
end
SG:Listen("HELLO_RELAY", function(hello, sender) sendEventsNewerThan(hello.ev, sender) end)

---------------------------------------------------------------------------
-- Calendario del WoW (experimental: requiere C_Calendar y permisos de guild)
---------------------------------------------------------------------------
function Ev:CreateInWowCalendar(e)
    if not C_Calendar or not C_Calendar.AddEvent then
        SG:Print("Este cliente no tiene calendario accesible; el evento queda solo en SolfaGuild.")
        return
    end
    local ok, err = pcall(function()
        local d = date("*t", e.start)
        local everyone = self:IsForEveryone(e)
        if everyone and C_Calendar.CreateGuildSignUpEvent then
            C_Calendar.CreateGuildSignUpEvent()
        else
            C_Calendar.CreatePlayerEvent()
        end
        C_Calendar.EventSetTitle(e.title)
        C_Calendar.EventSetDescription((e.desc or "") .. "\n[SolfaGuild]")
        C_Calendar.EventSetDate(d.month, d.day, d.year)
        C_Calendar.EventSetTime(d.hour, d.min)
        local other = (Enum and Enum.CalendarEventType and Enum.CalendarEventType.Other) or 4
        pcall(C_Calendar.EventSetType, other)
        if not everyone then
            local n = 0
            for _, name in ipairs(self:MatchingRoster(e)) do
                if name ~= SG:MyName() and n < 99 then
                    C_Calendar.EventInvite(name)
                    n = n + 1
                end
            end
        end
        C_Calendar.AddEvent()
    end)
    if ok then
        SG:Print("Evento añadido también al calendario del WoW.")
    else
        SG:Print("No se pudo crear en el calendario del WoW: " .. tostring(err))
    end
end

---------------------------------------------------------------------------
-- Avisos
---------------------------------------------------------------------------
local function remind(e, now_)
    SG.Popup:Card({
        kicker = "EVENTO DE LA GUILD",
        icon = "Interface\\Icons\\INV_Misc_Note_06",
        title = e.title,
        rank = date("%d/%m %H:%M", e.start) .. " - " .. (e.byMain or e.by),
        text = (now_ and SG:Fmt(SG.Texts.ui.eventNow, { title = e.title })
            or SG:Fmt(SG.Texts.ui.eventSoon, { title = e.title, min = math.max(1, math.floor((e.start - SG:Now()) / 60)) }))
            .. ((e.desc and e.desc ~= "") and ("\n\n" .. e.desc) or ""),
        button = "¡Allá voy!",
    })
end

function Ev:Tick()
    if not SG:Feature("events") or not IsInGuild() then return end
    SG.db.my.eventsReminded = SG.db.my.eventsReminded or {}
    local done = SG.db.my.eventsReminded
    local now = SG:Now()
    local lead = (SG:Cfg().eventReminder or 10) * 60
    for _, e in ipairs(self:Upcoming()) do
        if self:MatchesMe(e) then
            local kSoon, kNow = e.id .. ":soon", e.id .. ":now"
            if not done[kSoon] and now >= e.start - lead and now < e.start then
                done[kSoon] = now
                remind(e, false)
            elseif not done[kNow] and now >= e.start and now < e.start + 900 then
                done[kNow] = now
                done[kSoon] = done[kSoon] or now
                remind(e, true)
            end
        end
    end
end

function Ev:OnLogin()
    C_Timer.NewTicker(30, function() Ev:Tick() end)
    -- limpieza de eventos antiguos (más de 3 días)
    C_Timer.After(30, function()
        local gdb = SG:GuildDB()
        if not gdb then return end
        for id, e in pairs(gdb.events) do
            if (e.start or 0) < SG:Now() - 3 * 86400 then gdb.events[id] = nil end
        end
    end)
end
