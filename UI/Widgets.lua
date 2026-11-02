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

-- Lista con scroll. rows = { { text, right, header, color, button = {text, onClick}, tooltip = {lineas} } }
function W:List(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)
    scroll.rows = {}
    scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)

    function scroll:SetRows(rows)
        local width = self:GetWidth()
        content:SetWidth(width)
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
            if data.button then
                r.btn:SetText(data.button.text)
                r.btn:SetWidth(data.button.width or 90)
                r.btn:SetScript("OnClick", data.button.onClick)
                r.btn:Show()
                r.right:SetPoint("RIGHT", r.btn, "LEFT", -6, 0)
            else
                r.btn:Hide()
                r.right:SetPoint("RIGHT", -6, 0)
            end
            r:Show()
            y = y + 18
        end
        content:SetHeight(math.max(y, 10))
    end
    return scroll
end
