-- SolfaGuild - Botón del minimapa (arrastrable)

local _, ns = ...
local SG = ns.SG

local MM = SG:RegisterModule("Minimap", {})
local btn

local function place()
    local a = math.rad(SG.db.ui.minimapAngle or 200)
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
end

function MM:OnLogin()
    btn = CreateFrame("Button", "SolfaGuildMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20); bg:SetPoint("CENTER")
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(SG.ICON_PATH)
    icon:SetSize(20, 20); icon:SetPoint("CENTER")
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53); border:SetPoint("TOPLEFT")

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            SG.Social:ZoneCheck(GetRealZoneText(), true)
        else
            SG.UI:Toggle()
        end
    end)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            SG.db.ui.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
            place()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(SG.COLOR .. "SolfaGuild|r")
        GameTooltip:AddLine("Clic izquierdo: abrir ventana", 1, 1, 1)
        GameTooltip:AddLine("Clic derecho: buscar Solfamidas en tu zona", 1, 1, 1)
        GameTooltip:AddLine("Arrastrar: mover", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    place()
    btn:SetShown(not SG.db.ui.hideMinimap)
end

SG:Listen("MINIMAP_TOGGLE", function()
    if btn then btn:SetShown(not SG.db.ui.hideMinimap) end
end)
