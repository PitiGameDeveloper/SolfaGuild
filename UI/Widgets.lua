-- SolfaGuild - Widgets básicos de interfaz

local _, ns = ...
local SG = ns.SG

local W = {}
SG.W = W

function W:Button(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 100, h or 22)
    b:SetText(text)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function W:Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

-- Texto grande con tamaño y color propios (r, g, b de 0 a 1)
function W:BigLabel(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    local font, _, flags = fs:GetFont()
    fs:SetFont(font, size, flags)
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetShadowOffset(1, -1)
    return fs
end

function W:Check(parent, text, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.label:SetText(text or "")
    if onClick then cb:SetScript("OnClick", onClick) end
    return cb
end

function W:Edit(parent, w, numeric)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w or 120, 20)
    e:SetAutoFocus(false)
    if numeric then e:SetNumeric(true) end
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    return e
end

-- Lista con scroll. rows = { { text, right, header, color, button = {text, onClick}, tooltip = {lineas},
--   icon = {texture, onClick, tooltip, disabled (no se puede pulsar), dim (apagado)} } }
-- noScroll: lista fija sin barra de desplazamiento (para listas cortas)
function W:List(parent, noScroll)
    local scroll, content
    if noScroll then
        scroll = CreateFrame("Frame", nil, parent)
        content = scroll
    else
        scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
        content = CreateFrame("Frame", nil, scroll)
        content:SetSize(10, 10)
        scroll:SetScrollChild(content)
        scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)
    end
    scroll.rows = {}

    function scroll:SetRows(rows)
        if not noScroll then content:SetWidth(self:GetWidth()) end
        for _, r in ipairs(self.rows) do r:Hide() end
        local y = 0
        for i, data in ipairs(rows) do
            local r = self.rows[i]
            if not r then
                r = CreateFrame("Frame", nil, content)
                r:SetHeight(18)
                r.left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                r.left:SetPoint("LEFT", 4, 0)
                r.left:SetJustifyH("LEFT")
                r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                r.right:SetJustifyH("RIGHT")
                r.bg = r:CreateTexture(nil, "BACKGROUND")
                r.bg:SetAllPoints()
                r.btn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
                r.btn:SetSize(90, 18)
                r.btn:SetPoint("RIGHT", -2, 0)
                r.ibtn = CreateFrame("Button", nil, r)
                r.ibtn:SetSize(16, 16)
                r.ibtn:SetPoint("RIGHT", -4, 0)
                r.ibtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
                r.ibtn:SetScript("OnEnter", function(self)
                    if self.tip then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(self.tip)
                        GameTooltip:Show()
                    end
                end)
                r.ibtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                r:EnableMouse(true)
                r:SetScript("OnEnter", function(self)
                    if self.tooltip then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        for j, line in ipairs(self.tooltip) do
                            if j == 1 then GameTooltip:SetText(line) else GameTooltip:AddLine(line, 1, 1, 1) end
                        end
                        GameTooltip:Show()
                    end
                end)
                r:SetScript("OnLeave", function() GameTooltip:Hide() end)
                self.rows[i] = r
            end
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
            r.tooltip = data.tooltip
            r.left:SetText(data.text or "")
            r.right:SetText(data.right or "")
            if data.header then
                r.left:SetFontObject("GameFontNormal")
                r.bg:SetColorTexture(0.45, 0.25, 0.7, 0.25)
            else
                r.left:SetFontObject("GameFontHighlight")
                r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0)
            end
            r.ibtn:Hide()
            if data.icon then
                local ic = data.icon
                r.ibtn:SetNormalTexture(ic.texture)
                local tex = r.ibtn:GetNormalTexture()
                tex:SetDesaturated(ic.dim and true or false)
                tex:SetAlpha(ic.dim and 0.4 or 1)
                r.ibtn:SetEnabled(not ic.disabled)
                r.ibtn:SetScript("OnClick", ic.onClick)
                r.ibtn.tip = ic.tooltip
                r.ibtn:Show()
            end
            if data.button then
                r.btn:SetText(data.button.text)
                r.btn:SetWidth(data.button.width or 90)
                r.btn:SetScript("OnClick", data.button.onClick)
                r.btn:Show()
                r.right:SetPoint("RIGHT", r.btn, "LEFT", -6, 0)
            else
                r.btn:Hide()
                if data.icon then r.right:SetPoint("RIGHT", r.ibtn, "LEFT", -8, 0)
                else r.right:SetPoint("RIGHT", -6, 0) end
            end
            r:Show()
            y = y + 18
        end
        if not noScroll then content:SetHeight(math.max(y, 10)) end
    end
    return scroll
end
