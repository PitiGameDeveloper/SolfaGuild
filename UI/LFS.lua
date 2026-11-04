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
    b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.count:SetPoint("TOPRIGHT", -10, -11)
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

local function fillCard(b, d, myLevel, accounts)
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
    if locked then
        b.count:SetText("|cffff7777Nivel " .. d.min .. "|r")
    else
        local n = SG.LFS:CountFor(d, accounts)
        b.count:SetText(n .. (n == 1 and " compi" or " compis"))
    end
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
        local accounts = SG:Accounts()
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
            fillCard(b, d, level, accounts)
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

-- Iconos de función del buscador de grupo: el atlas si el cliente lo tiene y, si no, el archivo
local ROLE_FILE = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
local ROLE_ICON = {
    T = { atlas = "groupfinder-icon-role-large-tank", 0, 67 / 256, 67 / 256, 134 / 256 },
    H = { atlas = "groupfinder-icon-role-large-heal", 67 / 256, 134 / 256, 0, 67 / 256 },
    D = { atlas = "groupfinder-icon-role-large-dps", 67 / 256, 134 / 256, 67 / 256, 134 / 256 },
}

local function setRoleIcon(tex, role)
    local i = ROLE_ICON[role]
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(i.atlas) then
        tex:SetAtlas(i.atlas)
    else
        tex:SetTexture(ROLE_FILE)
        tex:SetTexCoord(i[1], i[2], i[3], i[4])
    end
end

-- Apagado, gris; encendido, con su color y brillo
local function setRoleLit(b, lit)
    b.icon:SetDesaturated(not lit)
    b.icon:SetAlpha(lit and 1 or 0.5)
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
    b.glow:SetSize(84, 84)
    setRoleIcon(b.glow, role)
    b.glow:SetBlendMode("ADD")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    setRoleIcon(b.icon, role)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    setRoleIcon(hl, role)
    hl:SetBlendMode("ADD")
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
    for _, role in ipairs({ "T", "H" }) do
        f[role]:SetScript("OnClick", function()
            f.need[role] = 1 - f.need[role]
            f.why:SetText("")
            updateForm(f)
        end)
    end
    -- DPS: clic derecho suma, clic izquierdo resta
    f.D:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f.D:SetScript("OnClick", function(_, button)
        local n = f.need.D + (button == "RightButton" and 1 or -1)
        f.need.D = math.max(0, math.min(MAX_DPS, n))
        f.why:SetText("")
        updateForm(f)
    end)
    f.D.count = W:BigLabel(f.D, 24)
    f.D.count:SetPoint("BOTTOMRIGHT", 2, -2)
    f.hint = W:Label(f.form, SG.Texts.ui.lfsDpsHint, "GameFontHighlightSmall")
    f.hint:SetPoint("TOP", 0, -98)
    f.why = W:Label(f.form, "", "GameFontHighlightSmall")
    f.why:SetPoint("BOTTOMLEFT", 0, 0)
    f.why:SetPoint("BOTTOMRIGHT", 0, 0)
    f.why:SetTextColor(1, 0.4, 0.4)

    -- estado de la búsqueda
    f.status = W:List(f, true)
    f.status:SetPoint("TOPLEFT", 26, -70)
    f.status:SetPoint("BOTTOMRIGHT", -26, 56)

    f.go = W:Button(f, "Buscar", 130, 24)
    f.go:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 20)
    f.close = W:Button(f, "Cerrar", 130, 24, function() f:Hide() end)
    f.close:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 20)
    f:Hide()
    return f
end

local function refreshStatus(f)
    local run = SG.LFS:Run()
    local rows = { { text = "Faltan: " .. run.need.T .. " tanque, " .. run.need.H .. " sanador, " .. run.need.D .. " DPS", header = true } }
    for name, s in pairs(run.slots) do
        local who = SG:ClassColor(s.class) .. s.char .. "|r"
        rows[#rows + 1] = { text = who .. " - " .. roleName(s.role),
            right = s.ready and "|cff55ff55invitando|r" or "|cffffd100cambiando de personaje|r" }
    end
    for name, o in pairs(run.offers) do
        rows[#rows + 1] = { text = SG:ClassColor(o.class) .. o.char .. "|r", right = "|cff999999pensándoselo|r" }
    end
    f.status:SetRows(rows)
end

local function refreshSearch()
    local f = search
    if not f or not f:IsShown() then return end
    local run = SG.LFS:Run()
    f.form:SetShown(not run)
    f.status:SetShown(run ~= nil)
    if run then
        f.dungeon:SetText("|cffffd100" .. run.d.name .. "|r")
        f.go:SetText("Cancelar búsqueda")
        f.go:Enable()
        f.go:SetScript("OnClick", function() SG.LFS:Cancel() end)
        refreshStatus(f)
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
        search.d = d
        search.need = { T = 0, H = 0, D = 0 }
        search.why:SetText("")
    end
    search:Show()
    refreshSearch()
end

SG:Listen("LFS_CHANGED", refreshSearch)

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
        r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.label:SetPoint("LEFT", r, "RIGHT", 3, 0)
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
    local x0 = -((#roles - 1) * slotW) / 2 - 30
    for i, r in ipairs(f.radios) do
        local role = roles[i]
        r:SetShown(role ~= nil)
        if role then
            r.role = role
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
            if not o.test then SG.LFS:Answer(nil) end
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
