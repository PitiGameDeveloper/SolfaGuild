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
local DRAGON = "|TInterface\\Icons\\INV_Misc_Head_Dragon_01:12:12|t"   -- mazmorras
local TAB_W, TAB_MARGIN = 90, 12
local TAB_ORDER = {
    { key = "profile",  text = "Perfil" },
    { key = "pvp",      text = "PvP" },
    { key = "dungeons", text = "PvE" },
    { key = "cositas",  text = "Cositas" },
    { key = "events",   text = "Eventos" },
    { key = "admin",    text = "GM" },
}

---------------------------------------------------------------------------
-- Helpers de ranking
---------------------------------------------------------------------------
local function num(v) return "|cffffffff" .. SG.Thousands(v) .. "|r" end
local function you(acc) return acc.mine and " |cff88ff88(tú)|r" or "" end

-- Valor de una categoría de Cositas con su formato (número, tiempo u oro)
local function cosValue(cat, v)
    if cat.money then return SG:FormatMoney(v, true) end
    if cat.time then return "|cffffffff" .. SG:FormatTime(v, true) .. "|r" end
    return num(v)
end

-- Oro de un personaje solo en monedas de oro (para que quepa en media ventana)
local function goldOnly(copper)
    return "|cffffd700" .. SG.Thousands(math.floor((tonumber(copper) or 0) / 10000)) .. "o|r"
end

local function charDungeons(c)
    local total = 0
    for _, k in pairs(c.dungeons or {}) do total = total + k end
    return total
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
        -- una opción puede traer su propio panel en vez de filas
        if m.build then
            m.panel = m.build(p)
            m.panel:ClearAllPoints()
            m.panel:SetPoint("TOPLEFT", 8, -32)
            m.panel:SetPoint("BOTTOMRIGHT", -28, 8)
            m.panel:Hide()
        end
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
        local m = modes[self.mode]
        for _, o in ipairs(modes) do
            if o.panel then o.panel:SetShown(o == m) end
        end
        self.list:SetShown(m.rows ~= nil)
        if m.panel then m.panel:Refresh() else self.list:SetRows(m.rows()) end
    end
    return p
end

---------------------------------------------------------------------------
-- Pestaña: Perfil
---------------------------------------------------------------------------
local function buildProfile(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()

    -- Bloques grandes de PvP y PvE
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

    -- abajo, dos listas iguales: tus personajes y las Cositas que lideras
    p.list = W:List(p, true)
    p.list:SetPoint("TOPLEFT", 8, -160)
    p.list:SetPoint("BOTTOMRIGHT", p, "BOTTOM", -4, 8)
    p.wins = W:List(p, true)
    p.wins:SetPoint("TOPLEFT", p, "TOP", 4, -160)
    p.wins:SetPoint("BOTTOMRIGHT", -8, 8)

    function p:Refresh()
        local t = SG.Milestones:MyTotals()
        pvp.rank:SetText(SG.PvP:LadderRankOf(t.acc) or "Sin rango")
        pvp.total:SetText(t.kills .. " asesinatos")
        pvp.week:SetText(t.killsWeek .. " esta semana")
        pve.rank:SetText(SG.DungeonTracker:LadderRankOf(t.acc) or "Sin rango")
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
                right = goldOnly(c.earned) .. "  |cffff5555" .. (c.kills or 0) .. "|r " .. SKULL
                    .. "  |cffb48cff" .. charDungeons(c) .. "|r " .. DRAGON,
                tooltip = { SG:ClassColor(c.class) .. name .. "|r", "Oro acumulado: " .. SG:FormatMoney(c.earned or 0, true),
                    "Asesinatos: " .. (c.kills or 0), "Mazmorras: " .. charDungeons(c) },
                icon = { texture = CROWN, disabled = isMain, dim = not isMain,  -- dorada solo la del main
                    tooltip = isMain and "Este es tu main" or "Hacer main",
                    onClick = function() SG:SetMain(name); p:Refresh() end },
            }
        end
        self.list:SetRows(rows)

        local wins = { { text = "Cositas en las que eres el mejor", header = true } }
        for _, it in ipairs(SG.Cositas:Board()) do
            if it.best and it.best.acc.mine then
                wins[#wins + 1] = {
                    text = "|cffffd100" .. SG:Fmt(it.cat.title) .. "|r",
                    right = cosValue(it.cat, it.best.value),
                    tooltip = { "|cffffd100" .. SG:Fmt(it.cat.title) .. "|r", SG:Fmt(it.cat.desc) },
                }
            end
        end
        if #wins == 1 then wins[2] = { text = "|cff888888eres un chingao|r" } end
        self.wins:SetRows(wins)
    end
    return p
end

---------------------------------------------------------------------------
-- Pestañas de ranking
---------------------------------------------------------------------------
local INDENT = "      "

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
    if #zones == 0 then rows[#rows + 1] = { text = "|cff888888Aún no ha caído nadie|r" } end

    blank()
    rows[#rows + 1] = { text = "Asesinatos coordinados", header = true }
    local teams = SG.PvP:Teams(week)
    for _, t in ipairs(teams) do
        local names = {}
        for _, acc in ipairs(t.accs) do names[#names + 1] = SG:ColoredMain(acc) .. you(acc) end
        rows[#rows + 1] = { text = table.concat(names, "  "), right = num(t.kills) .. " " .. SKULL }
    end
    if #teams == 0 then rows[#rows + 1] = { text = "|cff888888Aún no hay asesinatos en equipo|r" } end
    return rows
end

local function buildPvP(parent)
    return makeRankingPanel(parent, {
        { text = "Total", rows = function() return pvpRows(false) end },
        { text = "Semanal", rows = function() return pvpRows(true) end },
    })
end

-- Escalafón de mazmorras, igual que el de PvP
local function pveRows(week)
    local rows = { { text = "Ranking de mazmorras", header = true } }
    local ladder, nobody = SG.DungeonTracker:Ladder(week)
    for _, tier in ipairs(ladder) do
        rows[#rows + 1] = { text = "|cffffd100" .. tier.name .. "|r" }
        for _, it in ipairs(tier.members) do
            rows[#rows + 1] = { text = INDENT .. SG:ColoredMain(it.acc) .. you(it.acc), right = num(it.value) .. " " .. DRAGON }
        end
    end
    if nobody then   -- tú, aún sin mazmorras
        rows[#rows + 1] = { text = "|cff888888Sin mazmorras|r" }
        rows[#rows + 1] = { text = INDENT .. SG:ColoredMain(nobody.acc) .. you(nobody.acc), right = num(0) .. " " .. DRAGON }
    end

    local dungeons, groups = SG.DungeonTracker:Runs(week)
    rows[#rows + 1] = { text = " " }
    rows[#rows + 1] = { text = "Mazmorras más completadas", header = true }
    for _, d in ipairs(dungeons) do
        rows[#rows + 1] = { text = d.name }
        rows[#rows + 1] = { text = INDENT .. num(d.runs) .. " " .. DRAGON }
    end
    if #dungeons == 0 then rows[#rows + 1] = { text = "|cff888888Aún no se ha completado ninguna|r" } end

    rows[#rows + 1] = { text = " " }
    rows[#rows + 1] = { text = "Grupos con más mazmorras", header = true }
    for _, g in ipairs(groups) do
        local names = {}
        for _, acc in ipairs(g.accs) do names[#names + 1] = SG:ColoredMain(acc) .. you(acc) end
        rows[#rows + 1] = { text = table.concat(names, "  "), right = num(g.runs) .. " " .. DRAGON }
    end
    if #groups == 0 then rows[#rows + 1] = { text = "|cff888888Aún no hay mazmorras en grupo|r" } end
    return rows
end

local function buildDungeons(parent)
    return makeRankingPanel(parent, {
        { text = "Total", rows = function() return pveRows(false) end },
        { text = "Semanal", rows = function() return pveRows(true) end },
        { text = "LFS", build = function(p) return SG.UILFS:BuildPanel(p) end },
    })
end

-- Cositas: una fila por categoría con el mejor; al pasar el ratón, de qué va y tu valor
local function buildCositas(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()
    p.list = W:List(p)
    p.list:SetPoint("TOPLEFT", 8, -4)
    p.list:SetPoint("BOTTOMRIGHT", -28, 8)
    function p:Refresh()
        local rows = { { text = "Todos somos el mejor en algo", header = true } }
        if not SG:Feature("cositas") then
            rows[#rows + 1] = { text = "|cffff5555El GM ha desactivado las Cositas: no se cuenta nada nuevo.|r" }
        end
        for _, it in ipairs(SG.Cositas:Board()) do
            local cat = it.cat
            local function fmt(v) return cosValue(cat, v) end
            rows[#rows + 1] = {
                text = "|cffffd100" .. SG:Fmt(cat.title) .. "|r",
                right = it.best and (SG:ColoredMain(it.best.acc) .. you(it.best.acc) .. "   " .. fmt(it.best.value))
                    or "|cff888888nadie aún|r",
                tooltip = { "|cffffd100" .. SG:Fmt(cat.title) .. "|r", SG:Fmt(cat.desc), " ", "|cff88ff88Tú:|r " .. fmt(it.mine) },
            }
        end
        self.list:SetRows(rows)
    end
    return p
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
        -- sin permiso no se ve ni el botón: la lista sube arriba del todo
        local can = SG:CanCreateEvents()
        self.create:SetShown(can)
        self.info:SetShown(can)
        self.info:SetText("Tienes permiso para crear eventos.")
        self.list:SetPoint("TOPLEFT", 8, can and -32 or -4)
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
    { "pvp", "Rangos PvP" }, { "gold", "Hitos de oro" },
    { "dungeons", "Hitos de mazmorras" }, { "lfs", "LFS" },
    { "cositas", "Cositas" },
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
    p.lfsOffer = numField("LFS: segundos para contestar:", 10)
    p.lfsRelog = numField("LFS: min para cambiar de personaje:", 320)
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
        cfg.lfsOfferTime = tonumber(self.lfsOffer:GetText()) or cfg.lfsOfferTime
        cfg.lfsRelogTime = tonumber(self.lfsRelog:GetText()) or cfg.lfsRelogTime
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
        self.lfsOffer:SetText(cfg.lfsOfferTime); self.lfsRelog:SetText(cfg.lfsRelogTime)
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
                    SendChatMessage("¡Instálate el addon SolfaGuild para los rankings y eventos de la guild! ~SG~", "WHISPER", nil, SG:Target(m.name))
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
    profile = buildProfile, pvp = buildPvP, dungeons = buildDungeons,
    cositas = buildCositas, events = buildEvents, admin = buildAdmin,
}

-- Reparte las pestañas visibles por todo el ancho (la de GM solo la ve el GM, sin dejar hueco)
local function layoutTabs()
    local visible = {}
    for _, t in ipairs(TAB_ORDER) do
        local b = tabs[t.key]
        local show = t.key ~= "admin" or SG:IsAdmin()
        b:SetShown(show)
        if show then visible[#visible + 1] = b end
    end
    local n = #visible
    local gap = n > 1 and (frame:GetWidth() - 2 * TAB_MARGIN - n * TAB_W) / (n - 1) or 0
    for i, b in ipairs(visible) do
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", TAB_MARGIN + (i - 1) * (TAB_W + gap), 12)  -- pestañas abajo
    end
end

local function updateOnline()
    if not (frame and frame.onlineCount) then return end
    local n = 0
    for _, r in pairs(SG.roster) do
        if r.online then n = n + 1 end
    end
    frame.onlineCount:SetText(n)
end
-- aparte del refresco general, que se salta la pestaña del GM
SG:Listen("ROSTER_UPDATED", updateOnline)

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
    frame.sgTitle:SetPoint("TOPLEFT", 12, -6)
    frame.sgTitle:SetText(SG.ICON .. " SolfaGuild")

    -- Solfers conectados, junto al botón de cerrar
    frame.onlineIcon = frame:CreateTexture(nil, "OVERLAY")
    frame.onlineIcon:SetTexture("Interface\\AddOns\\SolfaGuild\\Media\\silbando")
    frame.onlineIcon:SetSize(16, 16)
    frame.onlineIcon:SetPoint("TOPRIGHT", -28, -4)
    frame.onlineCount = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.onlineCount:SetPoint("RIGHT", frame.onlineIcon, "LEFT", -3, 0)
    updateOnline()

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", 10, -30)
    body:SetPoint("BOTTOMRIGHT", -8, 40)

    for i, t in ipairs(TAB_ORDER) do
        local b = W:Button(frame, t.text, TAB_W, 24, function() UI:Show(t.key) end)
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
    layoutTabs()
    frame:Show()
    self:Refresh()
end

function UI:Refresh()
    if not frame or not frame:IsShown() then return end
    layoutTabs()
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
for _, ev in ipairs({ "DATA_UPDATED", "EVENTS_UPDATED", "SETTINGS_CHANGED", "ROSTER_UPDATED", "PVP_KILL", "DUNGEON_DONE", "LFS_CHANGED" }) do
    SG:Listen(ev, schedule)
end
