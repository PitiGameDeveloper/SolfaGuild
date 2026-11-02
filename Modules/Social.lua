-- SolfaGuild - Social: nota musical en susurros/invitaciones de la guild
-- y aviso al entrar en una zona con compañeros cerca.

local _, ns = ...
local SG = ns.SG

local Social = SG:RegisterModule("Social", {})
SG.Social = Social

local WHISPER_EVENTS = {
    CHAT_MSG_WHISPER = true,
    CHAT_MSG_WHISPER_INFORM = false, -- pon true si también quieres el icono en tus respuestas
}

---------------------------------------------------------------------------
-- Icono delante del nombre en los susurros
---------------------------------------------------------------------------
local function hookNames()
    if type(GetColoredName) == "function" then
        local orig = GetColoredName
        GetColoredName = function(event, ...)
            local name = orig(event, ...)
            if WHISPER_EVENTS[event] and SG:Feature("whisperIcon") then
                local author = select(2, ...)
                if author and SG:IsGuildMember(author) then
                    return SG.ICON .. name
                end
            end
            return name
        end
    else
        -- alternativa: icono delante del mensaje
        local function filter(_, event, msg, author, ...)
            if SG:Feature("whisperIcon") and SG:IsGuildMember(author) then
                return false, SG.ICON .. " " .. msg, author, ...
            end
        end
        ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", filter)
    end
end

---------------------------------------------------------------------------
-- Invitación a grupo de un Solfamida
---------------------------------------------------------------------------
SG:On("PARTY_INVITE_REQUEST", function(inviter)
    if not SG:Feature("inviteIcon") or not SG:IsGuildMember(inviter) then return end
    local short = SG:Short(inviter)
    local main = SG:MainOf(short)
    local who = short .. ((main ~= short) and (" (" .. main .. ")") or "")
    SG:Print(SG.ICON .. " |cffb48cff" .. who .. "|r, de los Solfamidas, te invita a su grupo.")
    C_Timer.After(0.05, function()
        for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
            local f = _G["StaticPopup" .. i]
            if f and f:IsShown() and f.which == "PARTY_INVITE" then
                local t = _G["StaticPopup" .. i .. "Text"]
                if t and t:GetText() and not t:GetText():find("clef", 1, true) then
                    t:SetText(SG.ICON .. " " .. t:GetText() .. "\n|cffb48cff(Solfamida)|r")
                    StaticPopup_Resize(f, f.which)
                end
            end
        end
    end)
end)

---------------------------------------------------------------------------
-- Aviso de zona (cada X min por zona, sin combate)
---------------------------------------------------------------------------
local pendingZone

function Social:MembersInZone(zone)
    local out = {}
    local me = SG:MyName()
    for name, r in pairs(SG.roster) do
        if r.online and r.zone == zone and name ~= me
            and not UnitInParty(name) and not UnitInRaid(name) then
            out[#out + 1] = { name = name, level = r.level, class = r.class, main = SG:MainOf(name) }
        end
    end
    table.sort(out, function(a, b) return a.level > b.level end)
    return out
end

function Social:ZoneCheck(zone, force)
    if not IsInGuild() or not SG:Feature("zoneNotify") then return end
    local inInstance = IsInInstance()
    if inInstance then return end
    local cd = (SG:Cfg().zoneCooldown or 30) * 60
    local last = SG.db.zoneNotify[zone] or 0
    if not force and SG:Now() - last < cd then return end
    SG.db.zoneNotify[zone] = SG:Now()
    local members = self:MembersInZone(zone)
    if #members == 0 then
        if force then SG:Print("No hay Solfamidas en " .. zone .. ".") end
        return
    end
    local rows = {}
    for _, m in ipairs(members) do
        local label = SG:ClassColor(m.class) .. m.name .. "|r (" .. m.level .. ")"
        if m.main ~= m.name then label = label .. " |cff999999" .. m.main .. "|r" end
        rows[#rows + 1] = { label = label, value = m.name, checked = false }
    end
    SG.Popup:PickList({
        title = SG:Fmt(SG.Texts.ui.zoneTitle, { zone = zone }),
        text = SG.Texts.ui.zoneText,
        rows = rows,
        button = "Susurrar",
        onAccept = function(sel)
            local msg = SG:Fmt(SG.Texts.ui.zoneWhisper, { zone = zone })
            for _, name in ipairs(sel) do SendChatMessage(msg, "WHISPER", nil, name) end
            if #sel > 0 then SG:Print("Avisados " .. #sel .. " Solfamida(s) en " .. zone .. ".") end
        end,
    })
end

local function onZone()
    local zone = GetRealZoneText()
    if not zone or zone == "" then return end
    pendingZone = zone
    SG:RequestRoster()
    -- damos tiempo al roster y esperamos a estar fuera de combate
    C_Timer.After(4, function()
        if pendingZone ~= zone then return end
        SG:WhenOutOfCombat(function()
            if GetRealZoneText() == zone then Social:ZoneCheck(zone) end
        end)
    end)
end

SG:On("ZONE_CHANGED_NEW_AREA", onZone)

function Social:OnLogin()
    hookNames()
    C_Timer.After(15, onZone)
end
