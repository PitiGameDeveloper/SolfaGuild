-- SolfaGuild - Ventanas del LFS: las tarjetas de mazmorras, "Looking for Solfamidas"
-- (quien busca) y la oferta que le llega a cada jugador.

local _, ns = ...
local SG = ns.SG
local W = SG.W

local UILFS = {}
SG.UILFS = UILFS

local CARD_H, CARD_GAP = 86, 8
local TICK = "Interface\\RaidFrame\\ReadyCheck-Ready"

local function dialogBackdrop(f)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
end

local function roleName(role) return SG.Texts.ui["lfsRole" .. role] or role end

---------------------------------------------------------------------------
-- Tarjeta de mazmorra
---------------------------------------------------------------------------
local function buildCard(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetHeight(CARD_H)
    b:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    b:SetBackdropBorderColor(0.65, 0.5, 0.2)

    b.base = b:CreateTexture(nil, "BACKGROUND")
    b.base:SetPoint("TOPLEFT", 3, -3); b.base:SetPoint("BOTTOMRIGHT", -3, 3)
    b.art = b:CreateTexture(nil, "BORDER")
    b.art:SetAllPoints(b.base)
    b.strip = b:CreateTexture(nil, "ARTWORK")
    b.strip:SetPoint("TOPLEFT", 3, -3); b.strip:SetPoint("TOPRIGHT", -3, -3)
    b.strip:SetHeight(30)
    b.strip:SetColorTexture(0, 0, 0, 0.5)

    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.name:SetPoint("TOPLEFT", 10, -10)
    b.name:SetPoint("RIGHT", -66, 0)
    b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    b.lock = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.lock:SetPoint("TOPRIGHT", -10, -11)
    b.level = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.level:SetPoint("BOTTOMLEFT", 10, 9)
    b.tick = b:CreateTexture(nil, "OVERLAY")
    b.tick:SetTexture(TICK)
    b.tick:SetSize(44, 44)
    b.tick:SetPoint("BOTTOMRIGHT", -8, 6)

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b.base)
    hl:SetColorTexture(1, 1, 1, 0.12)
    return b
end

local function fillCard(b, d, myLevel)
    local locked = myLevel < d.min
    local c = d.color or { 0.25, 0.25, 0.25 }
    b.base:SetColorTexture(c[1], c[2], c[3], 1)
    -- si el cliente no tiene la imagen, se queda el color de la mazmorra
    if d.art and b.art:SetTexture(d.art) ~= false then
        -- la franja central de la pantalla de carga (4:3) en una tarjeta de 4:1
        b.art:SetTexCoord(0, 1, 0.33, 0.67)
        b.art:Show()
    else
        b.art:Hide()
    end
    b.base:SetDesaturated(locked)
    b.art:SetDesaturated(locked)
    b:SetAlpha(locked and 0.55 or 1)
    b:SetEnabled(not locked)
    b.name:SetText(d.name)
    b.level:SetText("Nivel " .. d.min .. " - " .. d.max)
    b.tick:SetShown((SG:MyChar().dungeons[d.id] or 0) > 0)
    b.lock:SetText(locked and ("|cffff7777Nivel " .. d.min .. "|r") or "")
    b:SetScript("OnClick", function() UILFS:OpenSearch(d) end)
end

-- Panel de la pestaña: primero las disponibles y luego las bloqueadas,
-- cada grupo de mayor a menor nivel requerido.
function UILFS:BuildPanel(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()
    p.off = W:Label(p, "|cffff5555El GM ha desactivado el LFS.|r", "GameFontNormal")
    p.off:SetPoint("CENTER")
    p.scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    p.scroll:SetAllPoints()
    p.content = CreateFrame("Frame", nil, p.scroll)
    p.content:SetSize(10, 10)
    p.scroll:SetScrollChild(p.content)
    p.cards = {}
    p:SetScript("OnShow", function(self) self.scroll:SetVerticalScroll(0) end)

    local sorted = {}
    for _, d in ipairs(SG.Dungeons) do sorted[#sorted + 1] = d end
    table.sort(sorted, function(a, b)
        if a.min ~= b.min then return a.min > b.min end
        return a.name < b.name
    end)

    function p:Refresh()
        local on = SG:Feature("lfs")
        self.off:SetShown(not on)
        self.scroll:SetShown(on)
        if not on then return end
        local width = self.scroll:GetWidth()
        if width < 50 then return end
        local level = UnitLevel("player")
        local cardW = (width - CARD_GAP) / 2
        self.content:SetWidth(width)

        local order = {}
        for _, d in ipairs(sorted) do
            if d.min <= level then order[#order + 1] = d end
        end
        for _, d in ipairs(sorted) do
            if d.min > level then order[#order + 1] = d end
        end
        for i, d in ipairs(order) do
            local b = self.cards[i]
            if not b then
                b = buildCard(self.content)
                self.cards[i] = b
            end
            local slot = i - 1
            b:ClearAllPoints()
            b:SetWidth(cardW)
            b:SetPoint("TOPLEFT", (slot % 2) * (cardW + CARD_GAP), -math.floor(slot / 2) * (CARD_H + CARD_GAP))
            fillCard(b, d, level)
        end
        self.content:SetHeight(math.ceil(#order / 2) * (CARD_H + CARD_GAP))
    end
    return p
end

---------------------------------------------------------------------------
-- "Looking for Solfamidas": qué busco y cómo va
---------------------------------------------------------------------------
local search
local MAX_NEED, MAX_DPS = 4, 3   -- tú ocupas la quinta plaza del grupo

-- Los iconos del LFG del juego. Si el cliente no los tiene, otros del juego por su
-- identificador de archivo (inv_shield_06, spell_nature_healingtouch y
-- ability_meleedamage), recortados en redondo y con un aro.
local MEDIA = "Interface\\AddOns\\SolfaGuild\\Media\\"
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local ROLE_ATLAS = { T = "UI-LFG-RoleIcon-Tank", H = "UI-LFG-RoleIcon-Healer", D = "UI-LFG-RoleIcon-DPS" }
local ROLE_ICON = { T = 134952, H = 136041, D = 132223 }
local ROLE_GLOW = { T = { 0.25, 0.6, 1 }, H = { 0.25, 1, 0.4 }, D = { 1, 0.3, 0.25 } }

-- Apagado, gris; encendido, con su color y brillo
local function setRoleLit(b, lit)
    b.icon:SetDesaturated(not lit)
    b.icon:SetAlpha(lit and 1 or 0.5)
    if b.ring then
        b.ring:SetDesaturated(not lit)
        b.ring:SetAlpha(lit and 1 or 0.5)
    end
    b.glow:SetShown(lit)
end

local function updateForm(f)
    local need = f.need
    setRoleLit(f.T, need.T > 0)
    setRoleLit(f.H, need.H > 0)
    setRoleLit(f.D, need.D > 0)
    f.D.count:SetText(need.D)
    f.go:SetEnabled(need.T + need.H + need.D <= MAX_NEED)
end

local function buildRole(f, role, x)
    local b = CreateFrame("Button", nil, f.form)
    b:SetSize(64, 64)
    b:SetPoint("TOP", x, -6)
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetPoint("CENTER")
    b.glow:SetSize(100, 100)
    b.glow:SetTexture(MEDIA .. "rol_brillo")
    b.glow:SetBlendMode("ADD")
    local c = ROLE_GLOW[role]
    b.glow:SetVertexColor(c[1], c[2], c[3])
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetBlendMode("ADD")
    local atlas = ROLE_ATLAS[role]
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        b.icon:SetAtlas(atlas)
        hl:SetAtlas(atlas)
    else
        -- el icono, sin su borde de fábrica y recortado en redondo
        local mask = b:CreateMaskTexture()
        mask:SetAllPoints()
        mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        for _, tex in ipairs({ b.icon, hl }) do
            tex:SetTexture(ROLE_ICON[role])
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            tex:AddMaskTexture(mask)
        end
        b.ring = b:CreateTexture(nil, "ARTWORK", nil, 1)
        b.ring:SetAllPoints()
        b.ring:SetTexture(MEDIA .. "rol_aro")
    end
    hl:SetAlpha(0.3)
    b.label = W:Label(b, roleName(role), "GameFontHighlightSmall")
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -4)
    return b
end

local function buildSearch()
    local f = CreateFrame("Frame", "SolfaGuildLFSSearch", UIParent, "BackdropTemplate")
    dialogBackdrop(f)
    f:SetSize(380, 300)
    f:SetPoint("CENTER", 0, 60)
    tinsert(UISpecialFrames, "SolfaGuildLFSSearch")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -22)
    f.title:SetText(SG.Texts.ui.lfsTitle)
    f.dungeon = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.dungeon:SetPoint("TOP", f.title, "BOTTOM", 0, -6)

    -- formulario
    f.form = CreateFrame("Frame", nil, f)
    f.form:SetPoint("TOPLEFT", 26, -70)
    f.form:SetPoint("BOTTOMRIGHT", -26, 56)
    f.need = { T = 0, H = 0, D = 0 }
    f.T = buildRole(f, "T", -100)
    f.H = buildRole(f, "H", 0)
    f.D = buildRole(f, "D", 100)
    -- clic izquierdo añade, clic derecho quita
    local ROLE_MAX = { T = 1, H = 1, D = MAX_DPS }
    for role, max in pairs(ROLE_MAX) do
        f[role]:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        f[role]:SetScript("OnClick", function(_, button)
            local n = f.need[role] + (button == "LeftButton" and 1 or -1)
            f.need[role] = math.max(0, math.min(max, n))
            f.why:SetText("")
            updateForm(f)
        end)
    end
    f.D.count = W:BigLabel(f.D, 24)
    f.D.count:SetPoint("BOTTOMRIGHT", 2, -2)
    f.hint = W:Label(f.form, SG.Texts.ui.lfsDpsHint, "GameFontHighlightSmall")
    f.hint:SetPoint("TOP", 0, -98)
    f.why = W:Label(f.form, "", "GameFontHighlightSmall")
    f.why:SetPoint("BOTTOMLEFT", 0, 0)
    f.why:SetPoint("BOTTOMRIGHT", 0, 0)
    f.why:SetTextColor(1, 0.4, 0.4)

    -- estado de la búsqueda
    f.status = W:List(f)
    f.status:SetPoint("TOPLEFT", 26, -70)
    f.status:SetPoint("BOTTOMRIGHT", -44, 56)

    f.go = W:Button(f, "Buscar", 130, 24)
    f.go:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 20)
    f.close = W:Button(f, "Cerrar", 130, 24, function() f:Hide() end)
    f.close:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 20)
    f:Hide()
    return f
end

-- Orden y color de cada estado: primero quien va, después quien no
local STATE_ORDER = { inside = 1, invite = 2, yes = 2, relog = 2, wait = 3, no = 4, late = 4, busy = 4, lost = 4, taken = 4, failed = 4 }
local STATE_COLOR = { inside = "55ff55", invite = "55ff55", yes = "55ff55", relog = "ffd100", wait = "999999" }

-- Una fila por cada persona avisada. slots: plazas en curso, para saber en qué punto van.
local function answerRows(rows, answers, slots)
    local list = {}
    for name, a in pairs(answers) do
        local state = a.state
        local s = slots and slots[name]
        if s and state == "yes" then
            state = s.ready and "invite" or (s.char ~= name and "relog") or "yes"
        end
        list[#list + 1] = { char = a.char or name, class = a.class, role = a.role, state = state }
    end
    table.sort(list, function(x, y)
        local ox, oy = STATE_ORDER[x.state] or 9, STATE_ORDER[y.state] or 9
        if ox ~= oy then return ox < oy end
        return x.char < y.char
    end)
    for _, a in ipairs(list) do
        local going = STATE_ORDER[a.state] and STATE_ORDER[a.state] <= 2
        rows[#rows + 1] = { text = SG:ClassColor(a.class) .. a.char .. "|r" .. (going and a.role and (" - " .. roleName(a.role)) or ""),
            right = "|cff" .. (STATE_COLOR[a.state] or "ff7777") .. SG.Texts.ui.lfsState[a.state] .. "|r" }
    end
end

local function refreshStatus(f)
    local run = SG.LFS:Run()
    local missing = SG.LFS:NeedText(run.need)
    local rows = { { text = missing ~= "" and ("Faltan: " .. missing) or "Plazas cubiertas: esperando a que entren", header = true } }
    if run.exhausted then rows[#rows + 1] = { text = "|cffff7777No queda nadie más a quien avisar|r" } end
    answerRows(rows, run.answers, run.slots)
    f.status:SetRows(rows)
end

-- Cómo ha acabado: se queda a la vista hasta que se empieza otra
local function refreshResult(f, last)
    local missing = SG.LFS:NeedText(last.need)
    local rows = { { text = "|cff" .. (last.complete and "55ff55" or "ff7777") .. last.text .. "|r", header = true } }
    if missing ~= "" then rows[#rows + 1] = { text = "Faltan: " .. missing } end
    answerRows(rows, last.answers)
    f.status:SetRows(rows)
end

local function refreshSearch()
    local f = search
    if not f or not f:IsShown() then return end
    local run, last = SG.LFS:Run(), SG.LFS:LastResult()
    f.form:SetShown(not run and not last)
    f.status:SetShown(run ~= nil or last ~= nil)
    if run then
        f.dungeon:SetText("|cffffd100" .. run.d.name .. "|r")
        f.go:SetText("Cancelar búsqueda")
        f.go:Enable()
        f.go:SetScript("OnClick", function() SG.LFS:Cancel() end)
        refreshStatus(f)
    elseif last then
        f.dungeon:SetText("|cffffd100" .. last.d.name .. "|r")
        f.go:SetText("Nueva búsqueda")
        f.go:Enable()
        f.go:SetScript("OnClick", function()
            -- ya marcado lo que ha faltado
            f.d = last.d
            f.need = { T = last.need.T, H = last.need.H, D = math.min(last.need.D, MAX_DPS) }
            f.why:SetText("")
            SG.LFS:ClearResult()
            refreshSearch()
        end)
        refreshResult(f, last)
    else
        local d = f.d
        f.dungeon:SetText(d and ("|cffffd100" .. d.name .. "|r") or "")
        f.go:SetText("Buscar")
        updateForm(f)
        f.go:SetScript("OnClick", function()
            local need = f.need
            local ok, why = SG.LFS:Start(d, { T = need.T, H = need.H, D = need.D })
            f.why:SetText(ok and "" or (why or ""))
            refreshSearch()
        end)
    end
end

function UILFS:OpenSearch(d)
    search = search or buildSearch()
    if not SG.LFS:Run() then
        SG.LFS:ClearResult()
        search.d = d
        search.need = { T = 0, H = 0, D = 0 }
        search.why:SetText("")
    end
    search:Show()
    refreshSearch()
end

SG:Listen("LFS_CHANGED", refreshSearch)

-- Ha acabado: se avisa aunque hubieran cerrado la ventana
SG:Listen("LFS_FINISHED", function()
    if not search then return end
    search:Show()
    refreshSearch()
    local last = SG.LFS:LastResult()
    local sound = SOUNDKIT and (last and last.complete and SOUNDKIT.READY_CHECK or SOUNDKIT.RAID_WARNING)
    if sound then pcall(PlaySound, sound) end
end)

---------------------------------------------------------------------------
-- La oferta. Un botón de radio por función; si solo hay una, ya sale marcada.
-- No hay que elegir a ciegas: sin marcar, "Aceptar" está apagado.
---------------------------------------------------------------------------
local dialog

local function buildOffer()
    local f = CreateFrame("Frame", "SolfaGuildLFSOffer", UIParent, "BackdropTemplate")
    dialogBackdrop(f)
    f:SetSize(420, 230)
    f:SetPoint("CENTER", 0, 200)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -22)
    f.title:SetText(SG.Texts.ui.lfsTitle)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("TOPLEFT", 24, -50)
    f.text:SetPoint("RIGHT", -24, 0)
    f.text:SetJustifyH("CENTER")
    f.text:SetSpacing(2)

    f.radios = {}
    for i = 1, 3 do
        -- si el cliente no tiene el botón de radio, una casilla hace lo mismo
        local ok, r = pcall(CreateFrame, "CheckButton", nil, f, "UIRadioButtonTemplate")
        if not ok then r = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate") end
        r:SetSize(18, 18)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(14, 14)
        r.icon:SetPoint("LEFT", r, "RIGHT", 3, 0)
        r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.label:SetPoint("LEFT", r.icon, "RIGHT", 3, 0)
        r:SetScript("OnClick", function(self)
            for _, o in ipairs(f.radios) do o:SetChecked(o == self) end
            f.role = self.role
            f.yes:Enable()
        end)
        f.radios[i] = r
    end

    f.yes = W:Button(f, SG.Texts.ui.lfsYes, 130, 24, function()
        local role = f.role
        f:Hide()
        SG.LFS:Answer(role)
    end)
    f.yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 20)
    f.no = W:Button(f, SG.Texts.ui.lfsNo, 130, 24, function()
        f:Hide()
        SG.LFS:Answer(nil)
    end)
    f.no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 20)
    f:Hide()
    return f
end

-- offer = { dungeon, char, level, class, roles, secs, from, test }
local function showOffer(o)
    dialog = dialog or buildOffer()
    local f = dialog
    local who = SG:ClassColor(o.class) .. o.char .. "|r (" .. (o.level or "?") .. ")"
    local text = SG:Fmt(SG.Texts.ui.lfsOffer, { dungeon = "|cffffd100" .. o.dungeon.name .. "|r", char = who })
    if o.char ~= SG:MyName() then
        text = text .. "\n\n" .. SG:Fmt(SG.Texts.ui.lfsOtherChar, { char = who })
    elseif IsInGroup() and not SG:InMyGroup(o.from or "") then
        text = text .. "\n\n" .. SG.Texts.ui.lfsLeave
    end
    f.text:SetText(text)

    local roles = {}
    for _, role in ipairs(SG.LFS.ROLE_ORDER) do
        if o.roles:find(role, 1, true) then roles[#roles + 1] = role end
    end
    local slotW = 110
    local x0 = -((#roles - 1) * slotW) / 2 - 38
    for i, r in ipairs(f.radios) do
        local role = roles[i]
        r:SetShown(role ~= nil)
        if role then
            r.role = role
            -- el mismo icono que en la búsqueda; sin él, el de archivo sin su borde
            local atlas = ROLE_ATLAS[role]
            if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
                r.icon:SetAtlas(atlas)
            else
                r.icon:SetTexture(ROLE_ICON[role])
                r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            r.label:SetText(roleName(role))
            r:ClearAllPoints()
            r:SetPoint("BOTTOM", f, "BOTTOM", x0 + (i - 1) * slotW, 56)
            r:SetChecked(#roles == 1)
        end
    end
    f.role = #roles == 1 and roles[1] or nil
    f.yes:SetEnabled(f.role ~= nil)
    f:SetHeight(150 + f.text:GetStringHeight())

    -- tiempo para contestar: si no, cuenta como que no
    f.token = (f.token or 0) + 1
    local token = f.token
    C_Timer.After(o.secs or 30, function()
        if f.token == token and f:IsShown() then
            f:Hide()
            if not o.test then SG.LFS:Answer(nil, "late") end
        end
    end)
    f:Show()
    pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959)
end

SG:Listen("LFS_OFFER_SHOW", showOffer)
SG:Listen("LFS_OFFER_HIDE", function() if dialog then dialog:Hide() end end)

-- Prueba: /sg lfs
SG:Listen("TEST_LFS", function()
    local c = SG:MyChar()
    showOffer({ dungeon = SG.Dungeons[1], char = SG:MyName(), level = UnitLevel("player"), class = c.class,
        roles = "THD", secs = 30, test = true })
end)
