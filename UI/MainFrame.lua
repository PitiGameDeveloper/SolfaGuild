-- SolfaGuild - Ventana principal con pestañas

local _, ns = ...
local SG = ns.SG
local W = SG.W

local UI = {}
SG.UI = UI

local frame, tabs, panels, current = nil, {}, {}, nil
local SKULL = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:12:12|t"
local STAR  = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12:12|t"
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
local TAB_ORDER = {
    { key = "profile",  text = "Perfil" },
    { key = "pvp",      text = "PvP" },
    { key = "gold",     text = "Oro" },
    { key = "dungeons", text = "Mazmorras" },
    { key = "playtime", text = "Tiempo" },
    { key = "events",   text = "Eventos" },
    { key = "admin",    text = "GM" },
}

---------------------------------------------------------------------------
-- Helpers de ranking
---------------------------------------------------------------------------
local function altTooltip(acc, field, formatter)
    local lines = { SG:ColoredMain(acc) }
    local arr = {}
    for name, c in pairs(acc.chars) do arr[#arr + 1] = { name = name, c = c } end
    table.sort(arr, function(a, b) return a.name < b.name end)
    for _, it in ipairs(arr) do
        local c = it.c
        local v = field and formatter and formatter(c) or ""
        local tag = (it.name == acc.main) and " |cffffd100(main)|r" or ""
        if c.manual then tag = tag .. " |cff888888(sin datos)|r" end
        lines[#lines + 1] = SG:ClassColor(c.class) .. it.name .. "|r" .. (c.level and (" " .. c.level) or "") .. tag .. "   " .. v
    end
    return lines
end

local function rankingRows(list, formatter, perChar)
    local rows = {}
    for i, it in ipairs(list) do
        local medal = (i == 1 and "|cffffd700") or (i == 2 and "|cffc0c0c0") or (i == 3 and "|cffcd7f32") or "|cffaaaaaa"
        rows[#rows + 1] = {
            text = medal .. i .. ".|r  " .. SG:ColoredMain(it.acc)
                .. (it.acc.mine and " |cff88ff88(tú)|r" or ""),
            right = formatter(it.value),
            tooltip = altTooltip(it.acc, true, perChar),
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
    for i, m in ipairs(modes) do
        local b = W:Button(p, m.text, 120, 22, function() p.mode = i; p:Refresh() end)
        b:SetPoint("TOPLEFT", 8 + (i - 1) * 126, -4)
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

    local lbl = W:Label(p, "Tu main:", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", 12, -12)

    local dd = CreateFrame("Frame", "SolfaGuildMainDropDown", p, "UIDropDownMenuTemplate")
    dd:SetPoint("LEFT", lbl, "RIGHT", -6, -2)
    UIDropDownMenu_SetWidth(dd, 140)
    UIDropDownMenu_Initialize(dd, function()
        local names = {}
        for name in pairs(SG:MyGuildChars()) do names[#names + 1] = name end
        for name in pairs(SG.db.my.manualAlts) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.checked = (name == SG.db.my.main)
            info.func = function() SG:SetMain(name); UIDropDownMenu_SetText(dd, name) end
            UIDropDownMenu_AddButton(info)
        end
    end)
    p.dd = dd

    local hint = W:Label(p, "Tus alters se detectan solos al entrar con ellos. Puedes añadir uno a mano:", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 12, -44)
    local edit = W:Edit(p, 140)
    edit:SetPoint("TOPLEFT", 18, -62)
    local add = W:Button(p, "Añadir alter", 100, 22, function()
        SG:AddManualAlt(edit:GetText()); edit:SetText(""); p:Refresh()
    end)
    add:SetPoint("LEFT", edit, "RIGHT", 8, 0)

    p.summary = W:Label(p, "", "GameFontHighlight")
    p.summary:SetPoint("TOPLEFT", 12, -92)
    p.summary:SetWidth(600)
    p.summary:SetSpacing(3)

    p.list = W:List(p)
    p.list:SetPoint("TOPLEFT", 8, -170)
    p.list:SetPoint("BOTTOMRIGHT", -28, 8)

    function p:Refresh()
        UIDropDownMenu_SetText(dd, SG.db.my.main or SG:MyName())
        local t = SG.Milestones:MyTotals()
        local M, T = SG.Milestones, SG.Texts
        self.summary:SetText(
            "|cffffd100Rango PvP:|r " .. M:RankName(T.pvpRanks, t.kills) .. "  (" .. t.kills .. " asesinatos)\n" ..
            "|cffffd100Rango de mazmorras:|r " .. M:RankName(T.dungeonRanks, t.dungeons) .. "  (" .. t.dungeons .. " completadas)\n" ..
            "|cffffd100Oro de la cuenta:|r " .. SG:FormatMoney(SG:AccountSum(t.acc, "gold"), true) ..
            "   |cffffd100Recolectado:|r " .. SG:FormatMoney(t.earned, true) .. "\n" ..
            "|cffffd100Tiempo jugado:|r " .. SG:FormatTime(t.played))
        local rows = { { text = "Tus personajes en la guild", header = true } }
        local names = {}
        for name in pairs(t.acc.chars) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local c = t.acc.chars[name]
            local isMe = name == SG:MyName()
            rows[#rows + 1] = {
                text = SG:ClassColor(c.class) .. name .. "|r" .. (c.level and (" (" .. c.level .. ")") or "")
                    .. (name == t.acc.main and " " .. STAR .. " |cffffd100main|r" or "")
                    .. (c.manual and " |cff888888(añadido a mano)|r" or ""),
                right = c.manual and "" or (SG:FormatMoney(c.gold, true) .. "  |cffff5555" .. (c.kills or 0) .. "|r " .. SKULL),
                button = (not isMe) and { text = "Quitar", width = 60, onClick = function() SG:RemoveAlt(name); p:Refresh() end } or nil,
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

local function buildPvP(parent)
    local function extras(rows)
        rows[#rows + 1] = { text = " " }
        rows[#rows + 1] = { text = "Zonas más sangrientas", header = true }
        for i, z in ipairs(SG.PvP:TopZones(5)) do
            rows[#rows + 1] = { text = i .. ". " .. z.zone, right = num(z.kills) .. " " .. SKULL }
        end
        rows[#rows + 1] = { text = " " }
        rows[#rows + 1] = { text = "Parejas más despiadadas", header = true }
        local accs = SG:Accounts()
        local byMain = {}
        for _, a in pairs(accs) do byMain[a.main] = a end
        local function cm(n) local a = byMain[n]; return a and SG:ColoredMain(a) or n end
        for i, pr in ipairs(SG.PvP:TopPairs(5)) do
            rows[#rows + 1] = { text = i .. ". " .. cm(pr.an) .. " & " .. cm(pr.bn), right = num(pr.kills) .. " juntos" }
        end
        return rows
    end
    return makeRankingPanel(parent, {
        { text = "Total", rows = function()
            local rows = { { text = "Ranking de asesinatos (mundo abierto)", header = true } }
            for _, r in ipairs(rankingRows(SG:Ranking(function(a) return SG:AccountSum(a, "kills") end),
                function(v) return num(v) .. "  |cffb48cff" .. SG.Milestones:RankName(SG.Texts.pvpRanks, v) .. "|r" end,
                function(c) return (c.kills or 0) .. " " .. SKULL end)) do rows[#rows + 1] = r end
            return extras(rows)
        end },
        { text = "Esta semana", rows = function()
            local rows = { { text = "Asesinatos esta semana", header = true } }
            for _, r in ipairs(rankingRows(SG:Ranking(function(a) return SG:AccountWeekKills(a) end), num,
                function(c) return (c.weekKey == SG:WeekKey() and c.killsWeek or 0) .. " " .. SKULL end)) do rows[#rows + 1] = r end
            return extras(rows)
        end },
    })
end

local function buildGold(parent)
    local function money(v) return SG:FormatMoney(v, true) end
    return makeRankingPanel(parent, {
        { text = "Oro actual", rows = function()
            local rows = { { text = "Oro actual (todos los personajes del jugador)", header = true } }
            for _, r in ipairs(rankingRows(SG:Ranking(function(a) return SG:AccountSum(a, "gold") end), money,
                function(c) return SG:FormatMoney(c.gold or 0, true) end)) do rows[#rows + 1] = r end
            return rows
        end },
        { text = "Recolectado", rows = function()
            local rows = { { text = "Oro recolectado en total", header = true } }
            for _, r in ipairs(rankingRows(SG:Ranking(function(a) return SG:AccountSum(a, "earned") end), money,
                function(c) return SG:FormatMoney(c.earned or 0, true) end)) do rows[#rows + 1] = r end
            return rows
        end },
    })
end

local function buildDungeons(parent)
    return makeRankingPanel(parent, {
        { text = "Ranking", rows = function()
            local rows = { { text = "Mazmorras completadas", header = true } }
            local function dcount(c) local n = 0; for _, k in pairs(c.dungeons or {}) do n = n + k end; return n end
            for _, r in ipairs(rankingRows(SG:Ranking(function(a) return SG:AccountDungeons(a) end),
                function(v) return num(v) .. "  |cffb48cff" .. SG.Milestones:RankName(SG.Texts.dungeonRanks, v) .. "|r" end,
                function(c) return dcount(c) .. "" end)) do rows[#rows + 1] = r end
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
                function(v) return SG:FormatTime(v) end,
                function(c) return SG:FormatTime(c.played or 0) end)) do rows[#rows + 1] = r end
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
    { "zoneNotify", "Aviso de zona" }, { "events", "Eventos" },
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

    local y = -100
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
    frame.sgTitle:SetText(SG.ICON .. " SolfaGuild - Los Solfamidas")

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", 10, -60)
    body:SetPoint("BOTTOMRIGHT", -8, 8)

    for i, t in ipairs(TAB_ORDER) do
        local b = W:Button(frame, t.text, 90, 24, function() UI:Show(t.key) end)
        b:SetPoint("TOPLEFT", 12 + (i - 1) * 93, -30)
        tabs[t.key] = b
        local panel = BUILDERS[t.key](body)
        panel:Hide()
        panels[t.key] = panel
    end

    frame:SetScript("OnShow", function() SG:RequestRoster(); UI:Refresh() end)
    frame:Hide()
end

function UI:Show(key)
    if not frame then build() end
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
