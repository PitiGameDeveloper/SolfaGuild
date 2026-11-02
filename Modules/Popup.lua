-- SolfaGuild - Ventanas emergentes ("cartas" de hitos y listas para susurrar)
-- Nunca se muestran en combate: se encolan hasta que salgas de combate.

local _, ns = ...
local SG = ns.SG

local Popup = SG:RegisterModule("Popup", {})
SG.Popup = Popup

local queue = {}
local card

local function playSound()
    pcall(PlaySound, (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960)
end

local function buildCard()
    local f = CreateFrame("Frame", "SolfaGuildCard", UIParent, "BackdropTemplate")
    f:SetSize(380, 300)
    f:SetPoint("CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.kicker = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.kicker:SetPoint("TOP", 0, -22)
    f.kicker:SetTextColor(0.75, 0.55, 1)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(64, 64)
    f.icon:SetPoint("TOP", 0, -42)

    f.ring = f:CreateTexture(nil, "OVERLAY")
    f.ring:SetTexture("Interface\\AddOns\\SolfaGuild\\Media\\clef")
    f.ring:SetSize(22, 22)
    f.ring:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", 8, -6)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.title:SetPoint("TOP", f.icon, "BOTTOM", 0, -10)
    f.title:SetWidth(340)

    f.rank = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.rank:SetPoint("TOP", f.title, "BOTTOM", 0, -4)
    f.rank:SetTextColor(1, 0.82, 0)

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("TOP", f.rank, "BOTTOM", 0, -10)
    f.text:SetWidth(320)
    f.text:SetJustifyH("CENTER")
    f.text:SetSpacing(2)

    f.button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.button:SetSize(140, 24)
    f.button:SetPoint("BOTTOM", 0, 20)
    f.button:SetScript("OnClick", function()
        f:Hide()
        if f.onClose then f.onClose() end
        C_Timer.After(0.4, function() Popup:Next() end)
    end)
    f:Hide()
    return f
end

-- data = { kicker, title, rank, text, icon, button, onClose }
function Popup:Card(data)
    table.insert(queue, data)
    SG:WhenOutOfCombat(function() Popup:Next() end)
end

function Popup:Next()
    if SG:InCombat() then
        SG:WhenOutOfCombat(function() Popup:Next() end)
        return
    end
    card = card or buildCard()
    if card:IsShown() then return end
    local data = table.remove(queue, 1)
    if not data then return end
    card.kicker:SetText(data.kicker or "LOS SOLFAMIDAS")
    card.icon:SetTexture(data.icon or SG.ICON_PATH)
    card.title:SetText(data.title or "")
    card.rank:SetText(data.rank or "")
    card.text:SetText(data.text or "")
    card.button:SetText(data.button or SG.Texts.ui.popupButton)
    card.onClose = data.onClose
    local h = 190 + card.title:GetStringHeight() + card.text:GetStringHeight()
    card:SetHeight(math.max(260, h))
    card:Show()
    playSound()
end

---------------------------------------------------------------------------
-- Lista con casillas: { title, text, rows = { {label, value, checked, disabled} },
--   button, onAccept(selectedValues), extra (texto opcional de pie) }
---------------------------------------------------------------------------
local pick
local function buildPick()
    local f = CreateFrame("Frame", "SolfaGuildPick", UIParent, "BackdropTemplate")
    f:SetSize(380, 340)
    f:SetPoint("CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -22); f.title:SetWidth(340)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("TOP", f.title, "BOTTOM", 0, -8); f.text:SetWidth(330)
    f.text:SetJustifyH("LEFT")

    f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", 22, -110)
    f.scroll:SetPoint("BOTTOMRIGHT", -40, 56)
    f.content = CreateFrame("Frame", nil, f.scroll)
    f.content:SetSize(300, 10)
    f.scroll:SetScrollChild(f.content)
    f.checks = {}

    f.ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.ok:SetSize(130, 24); f.ok:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 20)
    f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancel:SetSize(130, 24); f.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 20)
    f.cancel:SetText("Ahora no")
    f.cancel:SetScript("OnClick", function() f:Hide() end)
    f:Hide()
    return f
end

function Popup:PickList(data)
    SG:WhenOutOfCombat(function()
        pick = pick or buildPick()
        local f = pick
        f.title:SetText(data.title or "")
        f.text:SetText(data.text or "")
        for _, cb in ipairs(f.checks) do cb:Hide() end
        for i, row in ipairs(data.rows or {}) do
            local cb = f.checks[i]
            if not cb then
                cb = CreateFrame("CheckButton", nil, f.content, "UICheckButtonTemplate")
                cb:SetSize(22, 22)
                cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
                f.checks[i] = cb
            end
            cb:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
            cb.label:SetText(row.label)
            cb.value = row.value
            cb:SetChecked(row.checked and true or false)
            if row.disabled then cb:Disable(); cb.label:SetTextColor(0.5, 0.5, 0.5)
            else cb:Enable(); cb.label:SetTextColor(1, 1, 1) end
            cb:Show()
        end
        f.content:SetHeight(math.max(10, #(data.rows or {}) * 22))
        f.ok:SetText(data.button or "Enviar")
        f.ok:SetScript("OnClick", function()
            local sel = {}
            for i = 1, #(data.rows or {}) do
                local cb = f.checks[i]
                if cb:GetChecked() and cb:IsEnabled() then sel[#sel + 1] = cb.value end
            end
            f:Hide()
            if data.onAccept then data.onAccept(sel) end
        end)
        f:Show()
        playSound()
    end)
end

SG:Listen("TEST_POPUP", function()
    local r = SG.Texts.pvpRanks[1]
    Popup:Card({
        kicker = "RANGO PVP DESBLOQUEADO",
        icon = r.icon, title = SG:Fmt(r.title), rank = SG:Fmt(r.name),
        text = SG:Fmt(r.text, { count = 1 }),
    })
end)
