-- SolfaGuild - SOS por campeo
-- Si un jugador enemigo te mata varias veces en mundo abierto en poco tiempo
-- (por defecto 2 veces en 10 minutos), sale una ventana para pedir refuerzos.
-- Si los pides, al resto de la guild con el addon le llega el aviso; quien
-- acude sale de su grupo, acepta solo la invitación y el campeado le invita.
-- Al convocar, el campeado prepara una banda (ver SOS:Call) para que quepan
-- todos y se les invita a la vez.

local _, ns = ...
local SG = ns.SG
local Comm = SG.Comm

local SOS = SG:RegisterModule("CampSOS", {})
SG.CampSOS = SOS

local band = bit.band
local TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
local HOSTILE     = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40

local KILL_WINDOW  = 10        -- s entre el último golpe enemigo y tu muerte
local SOS_COOLDOWN = 5 * 60    -- s sin volver a preguntar tras una petición
local ANSWER_TIME  = 10 * 60   -- s durante los que se puede acudir a un aviso

local lastHit           -- { name, t } último jugador enemigo que te dañó
local deaths = {}       -- { { name, t } } muertes recientes a manos de enemigos
local lastAsk = 0       -- GetTime() de la última ventana de "pedir refuerzos"
local mySOS             -- { id, t } petición propia en curso
local answering         -- { id, from, t } aviso al que he dicho que acudo
local seenSOS = {}      -- [id] = true (no repetir el mismo aviso)

local function isEnemyPlayer(flags)
    return band(flags, TYPE_PLAYER) > 0 and band(flags, HOSTILE) > 0
end

local function inOpenWorld()
    return not IsInInstance()
end

local function where()
    local zone = GetRealZoneText() or GetZoneText() or "?"
    local sub = GetSubZoneText and GetSubZoneText() or ""
    if sub ~= "" and sub ~= zone then return zone .. " (" .. sub .. ")" end
    return zone
end

local function cfg()
    local c = SG:Cfg()
    return c.campDeaths or 2, (c.campWindow or 10) * 60
end

---------------------------------------------------------------------------
-- Ventana con dos botones (no es segura: se puede mostrar en combate)
---------------------------------------------------------------------------
local function buildDialog(name)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(400, 170)
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

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(40, 40)
    f.icon:SetPoint("TOPLEFT", 22, -22)
    f.icon:SetTexture("Interface\\Icons\\Ability_Warrior_BattleShout")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -2)
    f.title:SetPoint("RIGHT", -22, 0)
    f.title:SetJustifyH("LEFT")

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("TOPLEFT", f.icon, "BOTTOMLEFT", 0, -10)
    f.text:SetPoint("RIGHT", -22, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetSpacing(2)

    f.yes = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.yes:SetSize(170, 24); f.yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 20)
    f.no = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.no:SetSize(170, 24); f.no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 20)
    f:Hide()
    return f
end

local askFrame, callFrame

-- data = { title, text, yes, no, onYes, onNo, timeout }
local function show(f, data)
    f.title:SetText(data.title)
    f.text:SetText(data.text)
    f.yes:SetText(data.yes)
    f.no:SetText(data.no)
    f.yes:SetScript("OnClick", function() f:Hide(); if data.onYes then data.onYes() end end)
    f.no:SetScript("OnClick", function() f:Hide(); if data.onNo then data.onNo() end end)
    f:SetHeight(110 + f.title:GetStringHeight() + f.text:GetStringHeight())
    f.token = (f.token or 0) + 1
    if data.timeout then
        local token = f.token
        C_Timer.After(data.timeout, function()
            if f.token == token and f:IsShown() then f:Hide() end
        end)
    end
    f:Show()
    pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959)
end

---------------------------------------------------------------------------
-- 1) Detectar el campeo
---------------------------------------------------------------------------
local function askForHelp(enemy, count, test)
    askFrame = askFrame or buildDialog("SolfaGuildCampAsk")
    if askFrame:IsShown() then return end
    askFrame:ClearAllPoints(); askFrame:SetPoint("CENTER", 0, 150)
    lastAsk = GetTime()
    show(askFrame, {
        title = SG:Fmt(SG.Texts.ui.campAskTitle),
        text = SG:Fmt(SG.Texts.ui.campAskText, { killer = enemy, count = count }),
        yes = SG.Texts.ui.campAskYes, no = SG.Texts.ui.campAskNo,
        onYes = function()
            if test then SG:Print("(Prueba) Aquí se avisaría a la guild.") else SOS:Call(enemy) end
        end,
    })
end

local function onKilledByPlayer(killer)
    local now = GetTime()
    local need, window = cfg()
    table.insert(deaths, { name = killer, t = now })
    -- solo cuentan las muertes dentro de la ventana de tiempo
    for i = #deaths, 1, -1 do
        if now - deaths[i].t > window then table.remove(deaths, i) end
    end
    SG:Debug("Muerte por jugador enemigo:", deaths[#deaths].name, "(" .. #deaths .. "/" .. need .. ")")
    if #deaths < need or now - lastAsk < SOS_COOLDOWN then return end
    -- el enemigo que más veces te ha matado
    local byName, enemy, best = {}, nil, 0
    for _, d in ipairs(deaths) do
        byName[d.name] = (byName[d.name] or 0) + 1
        if byName[d.name] > best then enemy, best = d.name, byName[d.name] end
    end
    local count = #deaths
    wipe(deaths)
    askForHelp(enemy, count)
end

-- Classic Era: el último jugador enemigo que te dañó, por el registro de combate
SG:On("COMBAT_LOG_EVENT_UNFILTERED", function()
    local _, sub, _, _, srcName, srcFlags, _, destGUID = CombatLogGetCurrentEventInfo()
    if not srcName or destGUID ~= UnitGUID("player") then return end
    if sub:sub(-7) == "_DAMAGE" and isEnemyPlayer(srcFlags or 0) then
        lastHit = { name = SG:Short(srcName), t = GetTime() }
    end
end)

-- Forever: lo dice el resumen de muerte del juego. La entrada más reciente es el
-- golpe final. Devuelve el nombre si fue un jugador; si no, nil.
local function killerFromRecap()
    local DR = C_DeathRecap
    if not (DR and DR.HasRecapEvents and SG:Open(DR.HasRecapEvents())) then return end
    local list = DR.GetRecapEvents()
    if type(list) ~= "table" then return end
    local best, bestT
    for _, ev in ipairs(list) do
        local t = SG:Open(ev.timestamp) or 0
        if not best or t >= bestT then best, bestT = ev, t end
    end
    if not best then return end
    local guid = SG:Open(best.sourceGUID)
    if type(guid) ~= "string" or not guid:find("^Player%-") or guid == SG:Open(UnitGUID("player")) then return end
    local name = SG:Open(best.sourceName)
    if type(name) == "string" and name ~= "" then return SG:Short(name) end
    return "?"
end

local lastDeathAt = 0   -- el juego repite PLAYER_DEAD al liberar el espíritu
SG:On("PLAYER_DEAD", function()
    if not SG:Feature("campSOS") or not inOpenWorld() then return end
    if SG.HasCombatLog then
        if lastHit and GetTime() - lastHit.t <= KILL_WINDOW then
            local name = lastHit.name
            lastHit = nil
            onKilledByPlayer(name)
        end
        return
    end
    local now = GetTime()
    if now - lastDeathAt < 30 then return end
    lastDeathAt = now
    C_Timer.After(1, function()
        SG:Try(function()
            local killer = killerFromRecap()
            if killer then onKilledByPlayer(killer) end
        end)
    end)
end)

---------------------------------------------------------------------------
-- Utilidades de grupo (API nueva si existe, si no la antigua)
---------------------------------------------------------------------------
local function leaveGroup()
    if C_PartyInfo and C_PartyInfo.LeaveParty then C_PartyInfo.LeaveParty() else LeaveParty() end
end

local function invite(name)
    name = SG:Target(name)
    if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(name) else InviteUnit(name) end
end

local function convertToRaid()
    if C_PartyInfo and C_PartyInfo.ConvertToRaid then C_PartyInfo.ConvertToRaid() else ConvertToRaid() end
end

local function inGroupWith(name) return SG:InMyGroup(name) end

---------------------------------------------------------------------------
-- 2) Pedir refuerzos: preparar la banda y avisar a la guild
--    - líder de un grupo: se pasa a banda ya;
--    - en un grupo sin ser líder: sale de él y monta el suyo;
--    - solo: la banda se crea en cuanto entre el primero (no hay banda de 1).
---------------------------------------------------------------------------
local coming = {}   -- [nombre] = { t = GetTime() de la última invitación, tries }, hasta que entra

function SOS:Call(enemy)
    mySOS = { id = SG:MyName() .. ":" .. SG:RandomId(6), t = GetTime() }
    wipe(coming)
    if IsInGroup() then
        if UnitIsGroupLeader("player") then
            if not IsInRaid() then convertToRaid() end
        else
            leaveGroup()
            SG:Print(SG.Texts.ui.campLeft)
        end
    end
    local zone = where()
    Comm:Send({ t = "CAMP_SOS", id = mySOS.id, zone = zone, enemy = enemy }, "GUILD")
    SG:Print(SG:Fmt(SG.Texts.ui.campSent, { zone = zone }))
end

Comm:Register("CAMP_SOS", function(msg, sender)
    if not SG:Feature("campSOS") or type(msg.id) ~= "string" or seenSOS[msg.id] then return end
    seenSOS[msg.id] = true
    local inHisGroup = inGroupWith(sender)
    callFrame = callFrame or buildDialog("SolfaGuildCampCall")
    callFrame:ClearAllPoints(); callFrame:SetPoint("CENTER", 0, 220)
    local main = SG:MainOf(sender)
    local who = sender .. ((main and main ~= sender) and (" (" .. main .. ")") or "")
    local text = SG:Fmt(SG.Texts.ui.campCallText, { who = who, zone = msg.zone or "?" })
    if IsInGroup() and not inHisGroup then text = text .. "\n\n" .. SG.Texts.ui.campCallLeave end
    show(callFrame, {
        title = SG:Fmt(SG.Texts.ui.campCallTitle),
        text = text,
        yes = SG.Texts.ui.campCallYes, no = SG.Texts.ui.campCallNo,
        timeout = ANSWER_TIME,
        onYes = function() SOS:Answer(msg.id, sender) end,
    })
end)

---------------------------------------------------------------------------
-- 3) Acudir: salir del grupo y, ya fuera, avisar al campeado para que invite
---------------------------------------------------------------------------
local waitingLeave   -- { id, victim, t } esperando a salir del grupo para avisar

local function sendGo(id, victim)
    waitingLeave = nil
    Comm:Send({ t = "CAMP_GO", id = id }, "WHISPER", victim)
end

function SOS:Answer(id, victim)
    answering = { id = id, from = victim, t = GetTime() }
    SG:Print(SG:Fmt(SG.Texts.ui.campGoing, { who = victim }))
    if inGroupWith(victim) then return end
    if not IsInGroup() then sendGo(id, victim); return end
    -- el aviso sale cuando el servidor confirme que ya no estamos en grupo
    -- (si no, la invitación fallaría); por si acaso, como mucho a los 5 s
    waitingLeave = { id = id, victim = victim, t = GetTime() }
    leaveGroup()
    C_Timer.After(5, function()
        if waitingLeave and waitingLeave.id == id then sendGo(id, victim) end
    end)
end

SG:On("GROUP_ROSTER_UPDATE", function()
    if waitingLeave and not IsInGroup() then sendGo(waitingLeave.id, waitingLeave.victim) end
end)

-- Aceptar sola la invitación del campeado
SG:On("PARTY_INVITE_REQUEST", function(inviter)
    if not answering or GetTime() - answering.t > ANSWER_TIME then return end
    if SG:Short(inviter) ~= answering.from then return end
    answering = nil
    AcceptGroup()
    C_Timer.After(0.1, function() if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end end)
end)

---------------------------------------------------------------------------
-- 4) El campeado invita a todos los que acuden a la vez
--    Se invita a todos en cuanto avisan, sin esperar. Si el juego rechaza
--    alguna por grupo lleno (yendo solo aún no hay banda), o si alguien no
--    entra, se le vuelve a invitar: al pasar a banda y cada pocos segundos.
---------------------------------------------------------------------------
local RETRY_EVERY = 8   -- s sin entrar para volver a invitar
local MAX_TRIES   = 4

local retryTicker

local function sendInvite(name)
    local c = coming[name]
    c.t, c.tries = GetTime(), c.tries + 1
    invite(name)
end

local function retry(force)
    if not mySOS then return end
    if IsInGroup() and not UnitIsGroupLeader("player") then return end
    -- en cuanto haya grupo, a banda (así no hay tope de 5)
    if IsInGroup() and not IsInRaid() then convertToRaid() end
    local now = GetTime()
    for name, c in pairs(coming) do
        if inGroupWith(name) then
            coming[name] = nil
        elseif c.tries >= MAX_TRIES and now - c.t >= RETRY_EVERY then
            coming[name] = nil
            SG:Print(SG:Fmt(SG.Texts.ui.campNoJoin, { who = name }))
        elseif force or now - c.t >= RETRY_EVERY then
            sendInvite(name)
        end
    end
    if not next(coming) and retryTicker then retryTicker:Cancel(); retryTicker = nil end
end

local wasRaid = false
SG:On("GROUP_ROSTER_UPDATE", function()
    local raid = IsInRaid()
    local becameRaid = raid and not wasRaid
    wasRaid = raid
    -- al pasar a banda se reinvita ya a quien se rechazó por grupo lleno
    if mySOS and next(coming) then SG:Try(retry, becameRaid) end
end)

Comm:Register("CAMP_GO", function(msg, sender)
    if not mySOS or msg.id ~= mySOS.id or GetTime() - mySOS.t > ANSWER_TIME then return end
    if inGroupWith(sender) or coming[sender] then return end
    coming[sender] = { t = 0, tries = 0 }
    SG:Print(SG:Fmt(SG.Texts.ui.campComing, { who = sender }))
    sendInvite(sender)
    if not retryTicker then retryTicker = C_Timer.NewTicker(2, function() SG:Try(retry) end) end
end)

---------------------------------------------------------------------------
-- Prueba: /sg campeo
---------------------------------------------------------------------------
SG:Listen("TEST_CAMP", function()
    askForHelp("Pruebadealianza", 3, true)
end)
