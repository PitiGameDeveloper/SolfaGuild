-- SolfaGuild - Ventana principal con pestañas

local _, ns = ...
local SG = ns.SG
local W = SG.W

local UI = {}
SG.UI = UI

local frame, tabs, panels, current = nil, {}, {}, nil
local SKULL = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:12:12|t"
local CROWN = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
local TAB_ORDER = {
    { key = "profile",  text = "Perfil" },
    { key = "pvp",      text = "PvP" },
    { key = "dungeons", text = "PvE" },
    { key = "gold",     text = "Oro" },
    { key = "playtime", text = "Tiempo" },
    { key = "events",   text = "Eventos" },
    { key = "admin",    text = "GM" },
}

---------------------------------------------------------------------------
-- Helpers de ranking
---------------------------------------------------------------------------
-- Cada jugador sale solo con su main, que engloba las estadísticas de todos sus personajes
local function rankingRows(list, formatter)
    local rows = {}
    for i, it in ipairs(list) do
        local medal = (i == 1 and "|cffffd700") or (i == 2 and "|cffc0c0c0") or (i == 3 and "|cffcd7f32") or "|cffaaaaaa"
        rows[#rows + 1] = {
            text = medal .. i .. ".|r  " .. SG:ColoredMain(it.acc)
                .. (it.acc.mine and " |cff88ff88(tú)|r" or ""),
            right = formatter(it.value),
        }
    end
    if #rows == 0 then rows[1] = { text = "|cff888888Aún no hay datos. ¡Sal ahí fuera!|r" } end
    return rows
end

---------------------------------------------------------------------------
-- Panel genérico de ranking con modos
---------------------------------------------------------------------------
local function makeRankingPanel(parent, modes)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()
    p.mode = 1
    p.modeButtons = {}
    -- botones de modo centrados en la ventana
    local BW, GAP = 120, 6
    local left = -(#modes * BW + (#modes - 1) * GAP) / 2
    for i, m in ipairs(modes) do
        local b = W:Button(p, m.text, BW, 22, function() p.mode = i; p:Refresh() end)
        b:SetPoint("TOPLEFT", p, "TOP", left + (i - 1) * (BW + GAP), -4)
        p.modeButtons[i] = b
    end
    p.list = W:List(p)
    p.list:SetPoint("TOPLEFT", 8, -32)
    p.list:SetPoint("BOTTOMRIGHT", -28, 8)
    function p:Refresh()
        for i, b in ipairs(self.modeButtons) do
            if i == self.mode then b:LockHighlight() else b:UnlockHighlight() end
        end
        self.list:SetRows(modes[self.mode].rows())
    end
    return p
end

---------------------------------------------------------------------------
-- Pestaña: Perfil
---------------------------------------------------------------------------
local function buildProfile(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()

    -- Dos bloques grandes: PvP a la izquierda y PvE a la derecha
    local function block(x, title)
        local b = {}
        b.title = W:BigLabel(p, 30, 1, 0.82, 0)
        b.title:SetPoint("TOP", p, "TOP", x, -14)
        b.title:SetText(title)
        b.rank = W:BigLabel(p, 30, 0.9, 0.15, 0.15)
        b.rank:SetPoint("TOP", p, "TOP", x, -54)
        b.total = W:BigLabel(p, 18, 1, 1, 1)
        b.total:SetPoint("TOP", p, "TOP", x, -96)
        b.week = W:BigLabel(p, 13, 1, 1, 1)
        b.week:SetPoint("TOP", p, "TOP", x + 40, -122)
        return b
    end
    local pvp = block(-165, "PvP")
    local pve = block(165, "PvE")

    p.list = W:List(p, true)
    p.list:SetPoint("TOPLEFT", 8, -160)
    p.list:SetPoint("BOTTOMRIGHT", -8, 8)

    function p:Refresh()
        local t = SG.Milestones:MyTotals()
        local M, T = SG.Milestones, SG.Texts
        pvp.rank:SetText(SG.PvP:LadderRankOf(t.acc) or "Sin rango")
        pvp.total:SetText(t.kills .. " asesinatos")
        pvp.week:SetText(t.killsWeek .. " esta semana")
        pve.rank:SetText(M:RankName(T.dungeonRanks, t.dungeons))
        pve.total:SetText(t.dungeons .. " dungeons")
        pve.week:SetText(t.dungeonsWeek .. " esta semana")

        local rows = { { text = "Tus personajes", header = true } }
        -- por nivel y, si empatan, por tiempo jugado
        local names = {}
        for name in pairs(t.acc.chars) do names[#names + 1] = name end
        table.sort(names, function(a, b)
            local ca, cb = t.acc.chars[a], t.acc.chars[b]
            local la, lb = ca.level or 0, cb.level or 0
            if la ~= lb then return la > lb end
            local pa, pb = ca.played or 0, cb.played or 0
            if pa ~= pb then return pa > pb end
            return a < b
        end)
        for _, name in ipairs(names) do
            local c = t.acc.chars[name]
            local isMain = name == t.acc.main
            rows[#rows + 1] = {
                text = SG:ClassColor(c.class) .. name .. "|r" .. (c.level and (" (" .. c.level .. ")") or "")
                    .. (isMain and "  |cffffd100main|r" or ""),
                right = SG:FormatMoney(c.earned or 0, true) .. "  |cffff5555" .. (c.kills or 0) .. "|r " .. SKULL,
                icon = { texture = CROWN, disabled = isMain, dim = not isMain,  -- dorada solo la del main
                    tooltip = isMain and "Este es tu main" or "Hacer main",
                    onClick = function() SG:SetMain(name); p:Refresh() end },
            }
        end
        self.list:SetRows(rows)
    end
    return p
end

---------------------------------------------------------------------------
-- Pestañas de ranking
---------------------------------------------------------------------------
local function num(v) return "|cffffffff" .. SG.Thousands(v) .. "|r" end

local INDENT = "      "
local function you(acc) return acc.mine and " |cff88ff88(tú)|r" or "" end

-- Las tres listas de PvP; week = true para contar solo esta semana
local function pvpRows(week)
    local rows = {}
    local function blank() rows[#rows + 1] = { text = " " } end

    -- Escalafón: los jugadores llenan los rangos de Texts.pvpLadder en orden
    rows[#rows + 1] = { text = "Ranking de asesinatos", header = true }
    local ladder, nobody = SG.PvP:Ladder(week)
    for _, tier in ipairs(ladder) do
        rows[#rows + 1] = { text = "|cffffd100" .. tier.name .. "|r" }
        for _, it in ipairs(tier.members) do
            rows[#rows + 1] = { text = INDENT .. SG:ColoredMain(it.acc) .. you(it.acc), right = num(it.value) .. " " .. SKULL }
        end
    end
    if nobody then   -- tú, aún sin asesinatos
        rows[#rows + 1] = { text = "|cff888888Sin asesinatos|r" }
        rows[#rows + 1] = { text = INDENT .. SG:ColoredMain(nobody.acc) .. you(nobody.acc), right = num(0) .. " " .. SKULL }
    end

    blank()
    rows[#rows + 1] = { text = "Zonas más sangrientas", header = true }
    local zones = SG.PvP:Zones(week)
    for _, z in ipairs(zones) do
        rows[#rows + 1] = { text = z.zone }
        rows[#rows + 1] = { text = INDENT .. num(z.kills) .. " " .. SKULL }
    end
    if #zones == 0 then rows[#rows + 1] = { text = "|cff888888Aún no ha caído nadie.|r" } end

    blank()
    rows[#rows + 1] = { text = "Asesinatos coordinados", header = true }
    local teams = SG.PvP:Teams(week)
    for _, t in ipairs(teams) do
        local names = {}
        for _, acc in ipairs(t.accs) do names[#names + 1] = SG:ColoredMain(acc) .. you(acc) end
        rows[#rows + 1] = { text = table.concat(names, "  "), right = num(t.kills) .. " " .. SKULL }
    end
    if #teams == 0 then rows[#rows + 1] = { text = "|cff888888Aún no hay asesinatos en equipo.|r" } end
    return rows
end

local function buildPvP(parent)
    return makeRankingPanel(parent, {
        { text = "Total", rows = function() return pvpRows(false) end },
        { text = "Semanal", rows = function() return pvpRows(true) end },
    })
end

local function buildGold(parent)
    local function money(v) return SG:FormatMoney(v, true) end
    return makeRankingPanel(parent, {
        { text = "Acumulado", rows = function()
            local rows = { { text = "Oro acumulado (todos los personajes del jugador)", header = true } }
            for _, r in ipairs(rankingRows(SG:Ranking(function(a) return SG:AccountSum(a, "earned") end), money)) do rows[#rows + 1] = r end
            return rows
        end },
    })
end

local function buildDungeons(parent)
    return makeRankingPanel(parent, {
        { text = "Ranking", rows = function()
            local rows = { { text = "Mazmorras completadas", header = true } }
            for _, r in ipairs(rankingRows(SG:Ranking(function(a) return SG:AccountDungeons(a) end),
                function(v) return num(v) .. "  |cffb48cff" .. SG.Milestones:RankName(SG.Texts.dungeonRanks, v) .. "|r" end)) do rows[#rows + 1] = r end
            return rows
        end },
        { text = "Para mi nivel", rows = function()
            local lvl = UnitLevel("player")
            local rows = { { text = "Mazmorras para nivel " .. lvl, header = true } }
            local list = SG.DungeonHelper:ForLevel(lvl)
            if #list == 0 then rows[#rows + 1] = { text = "|cff888888Ninguna en rango ahora mismo.|r" } end
            for _, d in ipairs(list) do
                local done = SG.DungeonTracker:CharDone(SG:MyName(), d.id)
                local cands = SG.DungeonHelper:Candidates(d)
                local online = 0
                for _, c in ipairs(cands) do if c.online then online = online + 1 end end
                rows[#rows + 1] = {
                    text = d.name .. " |cff999999(" .. d.min .. "-" .. d.max .. ")|r" .. (done and " " .. CHECK or ""),
                    right = online .. " compis online",
                    button = { text = "Buscar grupo", width = 100, onClick = function() SG.DungeonHelper:Announce(d) end },
                }
            end
            return rows
        end },
    })
end

local function buildPlaytime(parent)
    return makeRankingPanel(parent, {
        { text = "Más sudorosos", rows = function()
            local rows = { { text = "Tiempo de juego total", header = true } }
            for _, r in ipairs(rankingRows(SG:Ranking(function(a) return SG:AccountSum(a, "played") end),
                function(v) return SG:FormatTime(v) end)) do rows[#rows + 1] = r end
            return rows
        end },
    })
end

---------------------------------------------------------------------------
-- Pestaña: Eventos
---------------------------------------------------------------------------
local eventForm
local function buildEventForm()
    local f = CreateFrame("Frame", "SolfaGuildEventForm", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(420, 470)
    f:SetPoint("CENTER", 220, 0)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.sgTitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.sgTitle:SetPoint("TOP", 0, -6)
    f.sgTitle:SetText("Crear evento")
    tinsert(UISpecialFrames, "SolfaGuildEventForm")

    local y = -36
    local function field(label, w, numeric)
        local l = W:Label(f, label, "GameFontNormalSmall")
        l:SetPoint("TOPLEFT", 16, y)
        local e = W:Edit(f, w, numeric)
        e:SetPoint("TOPLEFT", 150, y + 4)
        y = y - 26
        return e
    end
    f.title = field("Título", 240)
    f.desc = field("Descripción", 240)
    f.date = field("Fecha (DD/MM/AAAA)", 100)
    f.time = field("Hora (HH:MM)", 60)
    y = y - 6
    local h = W:Label(f, "Filtros (deja vacío = todos):", "GameFontNormal")
    h:SetPoint("TOPLEFT", 16, y); y = y - 22
    f.rank = field("Rango guild (0=GM...)", 40, true)
    f.rankHint = W:Label(f, "", "GameFontHighlightSmall")
    f.rankHint:SetPoint("TOPLEFT", 200, y + 26 + 2)
    f.rankHint:SetWidth(200)
    f.minLevel = field("Nivel mínimo", 40, true)
    f.maxLevel = field("Nivel máximo", 40, true)
    f.minPvp = field("Rango PvP mín. (1-" .. #SG.Texts.pvpRanks .. ")", 40, true)
    f.minDung = field("Rango mazm. mín. (1-" .. #SG.Texts.dungeonRanks .. ")", 40, true)

    local cl = W:Label(f, "Clases (ninguna marcada = todas):", "GameFontNormalSmall")
    cl:SetPoint("TOPLEFT", 16, y); y = y - 18
    f.classChecks = {}
    for i, class in ipairs(SG.Events.CLASSES) do
        local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
        local cb = W:Check(f, SG:ClassColor(class) .. name .. "|r")
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        cb:SetPoint("TOPLEFT", 16 + col * 130, y - row * 22)
        cb.class = class
        f.classChecks[#f.classChecks + 1] = cb
    end
    y = y - 70
    f.wow = W:Check(f, "Crear también en el calendario del WoW (experimental)")
    f.wow:SetPoint("TOPLEFT", 16, y)

    local create = W:Button(f, "Crear evento", 140, 24, function()
        local d, m, yr = f.date:GetText():match("(%d+)/(%d+)/(%d+)")
        local hh, mm = f.time:GetText():match("(%d+):(%d+)")
        local title = strtrim(f.title:GetText() or "")
        if title == "" or not d or not hh then
            SG:Print("Rellena al menos título, fecha y hora.")
            return
        end
        local start = time({ year = tonumber(yr), month = tonumber(m), day = tonumber(d),
            hour = tonumber(hh), min = tonumber(mm), sec = 0 })
        local filter = {}
        local function n(e) local v = tonumber(e:GetText()); return v end
        filter.maxGuildRank = n(f.rank)
        filter.minLevel = n(f.minLevel)
        filter.maxLevel = n(f.maxLevel)
        filter.minPvp = n(f.minPvp)
        filter.minDung = n(f.minDung)
        local classes = {}
        for _, cb in ipairs(f.classChecks) do if cb:GetChecked() then classes[cb.class] = true end end
        if next(classes) then filter.classes = classes end
        SG.Events:Create({ title = title, desc = f.desc:GetText(), start = start, filter = filter }, f.wow:GetChecked())
        f:Hide()
        UI:Refresh()
    end)
    create:SetPoint("BOTTOM", 0, 14)

    function f:Reset()
        for _, e in ipairs({ f.title, f.desc, f.rank, f.minLevel, f.maxLevel, f.minPvp, f.minDung }) do e:SetText("") end
        f.date:SetText(date("%d/%m/%Y", time() + 86400))
        f.time:SetText("21:00")
        for _, cb in ipairs(f.classChecks) do cb:SetChecked(false) end
        f.wow:SetChecked(false)
        local names = {}
        local n = GuildControlGetNumRanks and GuildControlGetNumRanks() or 0
        for i = 1, n do names[#names + 1] = (i - 1) .. "=" .. (GuildControlGetRankName(i) or "?") end
        f.rankHint:SetText("|cff999999" .. table.concat(names, ", ") .. "|r")
    end
    f:Hide()
    return f
end

local function buildEvents(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()
    p.create = W:Button(p, "Crear evento", 130, 22, function()
        eventForm = eventForm or buildEventForm()
        eventForm:Reset()
        eventForm:Show()
    end)
    p.create:SetPoint("TOPLEFT", 8, -4)
    p.info = W:Label(p, "", "GameFontHighlightSmall")
    p.info:SetPoint("LEFT", p.create, "RIGHT", 10, 0)
    p.list = W:List(p)
    p.list:SetPoint("TOPLEFT", 8, -32)
    p.list:SetPoint("BOTTOMRIGHT", -28, 8)
    function p:Refresh()
        local can = SG:CanCreateEvents()
        if can then self.create:Enable() else self.create:Disable() end
        self.info:SetText(can and "Tienes permiso para crear eventos." or "|cff999999Solo los rangos/personas elegidos por el GM pueden crear eventos.|r")
        local rows = { { text = "Próximos eventos", header = true } }
        for _, e in ipairs(SG.Events:Upcoming()) do
            local mine = SG.Events:MatchesMe(e)
            local canDel = e.by == SG:MyName() or SG:IsAdmin() or SG:MainOf(e.by) == SG.db.my.main
            rows[#rows + 1] = {
                text = (mine and CHECK .. " " or "|cff666666-|r ") .. "|cffffd100" .. e.title .. "|r  |cff999999" .. SG:DayName(e.start) .. date(" %d/%m %H:%M", e.start) .. "|r",
                right = "|cffaaaaaa" .. SG.Events:FilterText(e) .. "|r",
                tooltip = { e.title, date("%d/%m/%Y %H:%M", e.start), "Creado por " .. (e.byMain or e.by), e.desc or "",
                    mine and "|cff55ff55Estás invitado|r" or "|cffff5555No cumples el filtro|r" },
                button = canDel and { text = "Borrar", width = 60, onClick = function() SG.Events:Delete(e.id); p:Refresh() end } or nil,
            }
        end
        if #rows == 1 then rows[2] = { text = "|cff888888No hay eventos programados.|r" } end
        self.list:SetRows(rows)
    end
    return p
end

---------------------------------------------------------------------------
-- Pestaña: GM
---------------------------------------------------------------------------
local FEATURE_NAMES = {
    { "pvp", "Rangos PvP" }, { "gold", "Hitos de oro" }, { "dungeons", "Hitos de mazmorras" },
    { "playtime", "Ranking de tiempo" }, { "dungeonHelper", "Ayudante de mazmorras" },
    { "whisperIcon", "Nota musical en susurros" }, { "inviteIcon", "Aviso de invitaciones" },
    { "zoneNotify", "Aviso de zona" }, { "events", "Eventos" }, { "campSOS", "SOS por campeo" },
}

local function buildAdmin(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()
    p.denied = W:Label(p, "|cffff5555Solo el GM (o cualquiera de sus alters) puede ver y cambiar esto.|r", "GameFontNormal")
    p.denied:SetPoint("CENTER")

    local box = CreateFrame("Frame", nil, p)
    box:SetAllPoints()
    p.box = box

    local t = W:Label(box, "Funciones activas para la guild", "GameFontNormal")
    t:SetPoint("TOPLEFT", 10, -6)
    p.features = {}
    for i, f in ipairs(FEATURE_NAMES) do
        local cb = W:Check(box, f[2])
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        cb:SetPoint("TOPLEFT", 10 + col * 200, -24 - row * 22)
        cb.key = f[1]
        p.features[#p.features + 1] = cb
    end

    local y = -122
    local function numField(label, x)
        local l = W:Label(box, label, "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", x, y)
        local e = W:Edit(box, 36, true)
        e:SetPoint("LEFT", l, "RIGHT", 8, 0)
        return e
    end
    p.zoneCd = numField("Aviso de zona cada (min):", 10)
    p.reminder = numField("Aviso de evento antes (min):", 320)
    y = y - 24
    p.dhBelow = numField("Mazmorras: niveles por debajo:", 10)
    p.dhAbove = numField("Niveles por encima:", 250)
    p.dhMax = numField("Desactivar a partir de nivel:", 420)
    y = y - 24
    p.campDeaths = numField("Campeo: muertes seguidas:", 10)
    p.campWindow = numField("en (min):", 250)

    y = y - 30
    local r = W:Label(box, "Rangos de guild que pueden crear eventos:", "GameFontNormal")
    r:SetPoint("TOPLEFT", 10, y)
    p.rankChecks = {}
    for i = 1, 10 do
        local cb = W:Check(box, "")
        local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
        cb:SetPoint("TOPLEFT", 10 + col * 125, y - 18 - row * 22)
        cb.rankIndex = i - 1
        p.rankChecks[i] = cb
    end
    y = y - 70
    local n = W:Label(box, "Mains con permiso a dedo (separados por comas):", "GameFontHighlightSmall")
    n:SetPoint("TOPLEFT", 10, y)
    p.names = W:Edit(box, 300)
    p.names:SetPoint("LEFT", n, "RIGHT", 8, 0)

    local save = W:Button(box, "Guardar y enviar a la guild", 200, 24, function() p:Save() end)
    save:SetPoint("TOPLEFT", 10, y - 26)

    p.missing = W:List(box)
    p.missing:SetPoint("TOPLEFT", 8, y - 58)
    p.missing:SetPoint("BOTTOMRIGHT", -28, 8)

    function p:Save()
        local cfg = SG:Cfg()
        for _, cb in ipairs(self.features) do cfg.features[cb.key] = cb:GetChecked() and true or false end
        cfg.zoneCooldown = tonumber(self.zoneCd:GetText()) or cfg.zoneCooldown
        cfg.eventReminder = tonumber(self.reminder:GetText()) or cfg.eventReminder
        cfg.dhBelow = tonumber(self.dhBelow:GetText()) or cfg.dhBelow
        cfg.dhAbove = tonumber(self.dhAbove:GetText()) or cfg.dhAbove
        cfg.dhMaxLevel = tonumber(self.dhMax:GetText()) or cfg.dhMaxLevel
        cfg.campDeaths = tonumber(self.campDeaths:GetText()) or cfg.campDeaths
        cfg.campWindow = tonumber(self.campWindow:GetText()) or cfg.campWindow
        cfg.eventRanks = {}
        for _, cb in ipairs(self.rankChecks) do if cb:IsShown() and cb:GetChecked() then cfg.eventRanks[cb.rankIndex] = true end end
        cfg.eventNames = {}
        for name in (self.names:GetText() or ""):gmatch("[^,%s]+") do cfg.eventNames[name] = true end
        SG.Settings:Publish()
    end

    function p:Refresh()
        local admin = SG:IsAdmin()
        self.box:SetShown(admin)
        self.denied:SetShown(not admin)
        if not admin then return end
        local cfg = SG:Cfg()
        for _, cb in ipairs(self.features) do cb:SetChecked(cfg.features[cb.key] ~= false) end
        self.zoneCd:SetText(cfg.zoneCooldown); self.reminder:SetText(cfg.eventReminder)
        self.dhBelow:SetText(cfg.dhBelow); self.dhAbove:SetText(cfg.dhAbove); self.dhMax:SetText(cfg.dhMaxLevel)
        self.campDeaths:SetText(cfg.campDeaths); self.campWindow:SetText(cfg.campWindow)
        local nr = GuildControlGetNumRanks and GuildControlGetNumRanks() or 0
        for i, cb in ipairs(self.rankChecks) do
            if i <= nr then
                cb.label:SetText((GuildControlGetRankName(i) or ("Rango " .. (i - 1))))
                cb:SetChecked(cfg.eventRanks[i - 1] and true or false)
                cb:Show()
            else cb:Hide() end
        end
        local names = {}
        for name in pairs(cfg.eventNames) do names[#names + 1] = name end
        table.sort(names)
        self.names:SetText(table.concat(names, ", "))

        -- Miembros sin addon
        local known = {}
        for _, acc in pairs(SG:Accounts()) do for name in pairs(acc.chars) do known[name] = true end end
        local gdb = SG:GuildDB()
        for name in pairs(gdb and gdb.seen or {}) do known[name] = true end
        local miss = {}
        for name, rr in pairs(SG.roster) do
            if not known[name] then miss[#miss + 1] = { name = name, r = rr } end
        end
        table.sort(miss, function(a, b)
            if a.r.online ~= b.r.online then return a.r.online end
            return a.name < b.name
        end)
        local rows = { { text = "Miembros sin el addon (" .. #miss .. ")", header = true } }
        for _, m in ipairs(miss) do
            rows[#rows + 1] = {
                text = SG:ClassColor(m.r.class) .. m.name .. "|r (" .. m.r.level .. ") |cff999999" .. (m.r.rank or "") .. "|r",
                right = m.r.online and "|cff55ff55online|r" or "|cff666666offline|r",
                button = m.r.online and { text = "Avisar", width = 60, onClick = function()
                    SendChatMessage("¡Instálate el addon SolfaGuild para los rankings y eventos de la guild! ~SG~", "WHISPER", nil, m.name)
                end } or nil,
            }
        end
        self.missing:SetRows(rows)
    end
    return p
end

---------------------------------------------------------------------------
-- Ventana
---------------------------------------------------------------------------
local BUILDERS = {
    profile = buildProfile, pvp = buildPvP, gold = buildGold, dungeons = buildDungeons,
    playtime = buildPlaytime, events = buildEvents, admin = buildAdmin,
}

local function build()
    frame = CreateFrame("Frame", "SolfaGuildFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(680, 500)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true); frame:SetMovable(true); frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "SolfaGuildFrame")
    frame.sgTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.sgTitle:SetPoint("TOP", 0, -6)
    frame.sgTitle:SetText(SG.ICON .. " SolfaGuild")

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", 10, -30)
    body:SetPoint("BOTTOMRIGHT", -8, 40)

    for i, t in ipairs(TAB_ORDER) do
        local b = W:Button(frame, t.text, 90, 24, function() UI:Show(t.key) end)
        b:SetPoint("BOTTOMLEFT", 12 + (i - 1) * 93, 12)  -- pestañas abajo
        tabs[t.key] = b
        local panel = BUILDERS[t.key](body)
        panel:Hide()
        panels[t.key] = panel
    end

    frame:SetScript("OnShow", function() SG:RequestRoster(); UI:Refresh() end)
    frame:Hide()
end

function UI:Show(key)
    if not frame then
        -- si falla al construirla, no dejamos una ventana a medias
        local ok, err = pcall(build)
        if not ok then
            if frame then frame:Hide() end
            frame, tabs, panels = nil, {}, {}
            error(err, 0)
        end
    end
    current = key or current or "profile"
    for k, p in pairs(panels) do p:SetShown(k == current) end
    for k, b in pairs(tabs) do
        if k == current then b:LockHighlight() else b:UnlockHighlight() end
    end
    tabs.admin:SetShown(SG:IsAdmin())
    frame:Show()
    self:Refresh()
end

function UI:Refresh()
    if not frame or not frame:IsShown() then return end
    tabs.admin:SetShown(SG:IsAdmin())
    local p = panels[current]
    if p and p.Refresh then p:Refresh() end
end

function UI:Toggle()
    if frame and frame:IsShown() then frame:Hide() else self:Show() end
end

-- refresco automático (con un pequeño retraso para agrupar actualizaciones)
local pending
local function schedule()
    if pending then return end
    pending = true
    C_Timer.After(1, function()
        pending = false
        -- no pisamos lo que el GM está editando
        if current ~= "admin" then UI:Refresh() end
    end)
end
for _, ev in ipairs({ "DATA_UPDATED", "EVENTS_UPDATED", "SETTINGS_CHANGED", "ROSTER_UPDATED", "PVP_KILL", "DUNGEON_DONE" }) do
    SG:Listen(ev, schedule)
end
