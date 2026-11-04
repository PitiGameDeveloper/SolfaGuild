-- SolfaGuild - Mapa de la guild: en el mapa del mundo se ve a los Solfamidas con el color
-- de su clase y, al pasar el ratón por encima, su nombre.
--
-- Para no gastar: solo se envía la posición mientras alguien tiene el mapa abierto. Quien lo abre
-- avisa (MAP_ON) y los demás le contestan durante un rato (POS), y solo si se han movido. Si nadie
-- mira, no sale ningún mensaje. Dentro de una instancia no se envía nunca: en banda no cuesta nada.

local _, ns = ...
local SG = ns.SG
local Comm = SG.Comm

local M = SG:RegisterModule("GuildMap", {})
SG.GuildMap = M

local SEND_EVERY = 4    -- segundos entre posiciones mientras alguien mira
local WANT_TIME  = 30   -- segundos que se sigue enviando después de un MAP_ON
local ASK_EVERY  = 20   -- quien mira repite el MAP_ON cada tanto
local ASK_MIN    = 10   -- abrir y cerrar el mapa sin parar no repite el aviso
local KEEPALIVE  = 20   -- aunque no se mueva, se envía cada tanto
local EXPIRE     = 50   -- sin noticias de alguien en este tiempo, se le quita del mapa
local VIEW_EVERY = 5    -- segundos entre repasos del mapa abierto
local PRECISION  = 10000   -- las coordenadas viajan como enteros de 0 a 10000
local MIN_MOVE   = 10   -- movimiento mínimo para enviar otra vez (0,1 % del mapa)
local PIN_SIZE   = 12
local TEXTURE    = "Interface\\AddOns\\SolfaGuild\\Media\\pin"

local function isOn() return SG:Feature("guildMap") end

---------------------------------------------------------------------------
-- Enviar mi posición (solo mientras alguien mira)
---------------------------------------------------------------------------
local wantUntil, sendTicker, forced = 0, nil, false
local sent = {}   -- lo último enviado: m, x, y, t

-- Mapa y coordenadas (enteros) del jugador. nil dentro de instancias o si el juego no lo da.
local function myPosition()
    if IsInInstance() then return nil end
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local map = SG:Open(C_Map.GetBestMapForUnit("player"))
    if not map then return nil end
    local pos = SG:Open(C_Map.GetPlayerMapPosition(map, "player"))
    if not pos then return nil end
    local x, y = pos:GetXY()
    x, y = SG:Open(x), SG:Open(y)
    if not x or not y or (x == 0 and y == 0) then return nil end
    return map, math.floor(x * PRECISION + 0.5), math.floor(y * PRECISION + 0.5)
end

local function sendPosition()
    if not isOn() or SG:InCombat() then return end
    local map, x, y = myPosition()
    if not map then
        -- ya no se me puede ver: que me quiten del mapa, una sola vez
        if sent.m and Comm:SendLossy({ t = "POS" }) then sent.m = nil end
        forced = false
        return
    end
    local now = GetTime()
    local changed = map ~= sent.m or math.abs(x - sent.x) >= MIN_MOVE or math.abs(y - sent.y) >= MIN_MOVE
    if not (forced or changed or now - sent.t >= KEEPALIVE) then return end
    if Comm:SendLossy({ t = "POS", m = map, x = x, y = y }) then
        sent.m, sent.x, sent.y, sent.t = map, x, y, now
        forced = false
    end
end

local function sendTick()
    if GetTime() >= wantUntil then
        sendTicker:Cancel()
        sendTicker = nil
        sent.m = nil
        return
    end
    sendPosition()
end

Comm:Register("MAP_ON", function(_, _, channel)
    if channel ~= "GUILD" then return end
    wantUntil = GetTime() + WANT_TIME
    forced = true
    if not sendTicker then
        sendTicker = C_Timer.NewTicker(SEND_EVERY, function() SG:Try(sendTick) end)
        sendPosition()
    end
end)

---------------------------------------------------------------------------
-- Ver a los demás
---------------------------------------------------------------------------
local positions = {}   -- [nombre] = { m, x, y, t }
local pins = {}        -- [nombre] = marca del mapa
M.positions, M.pins = positions, pins

local provider, canvas
local opened, viewTicker, lastAsk = false, nil, nil

-- Pasa un punto de un mapa a otro: la zona de alguien al continente o la zona que estoy viendo.
-- nil si no sale en ese mapa, como otro continente.
local function project(src, x, y, shown)
    if src == shown then return x, y end
    if not C_Map then return nil end
    if C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D then
        local inst, world = C_Map.GetWorldPosFromMapPos(src, CreateVector2D(x, y))
        if inst and world then
            local _, pos = C_Map.GetMapPosFromWorldPos(inst, world, shown)
            if pos then return pos:GetXY() end
        end
    end
    -- el mapa de todo el mundo tiene varios continentes: no vale la posición en el mundo
    if C_Map.GetMapRectOnMap then
        local left, right, top, bottom = C_Map.GetMapRectOnMap(src, shown)
        if left and right and top and bottom and right > left and bottom > top then
            return left + x * (right - left), top + y * (bottom - top)
        end
    end
    return nil
end

local function canvasScale()
    local map = WorldMapFrame
    return map.GetCanvasScale and map:GetCanvasScale() or canvas:GetScale() or 1
end

-- Por encima del mapa y a la altura de los demás puntos de interés
local function pinLevel()
    local mgr = WorldMapFrame.GetPinFrameLevelsManager and WorldMapFrame:GetPinFrameLevelsManager()
    if mgr and mgr.GetValidFrameLevel then
        local ok, level = pcall(mgr.GetValidFrameLevel, mgr, "PIN_FRAME_LEVEL_AREA_POI")
        if ok and level then return level end
    end
    return canvas:GetFrameLevel() + 100
end

-- Tooltip con todos los que hay debajo del ratón: en una capital salen unos encima de otros
local function pinEnter(self)
    local names = {}
    for name, pin in pairs(pins) do
        if pin:IsShown() and pin:IsMouseOver() then names[#names + 1] = name end
    end
    if #names == 0 then names[1] = self.who end
    table.sort(names)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    for _, name in ipairs(names) do
        GameTooltip:AddLine(SG:ClassColor(pins[name].class) .. name .. "|r")
    end
    GameTooltip:Show()
end

local function pinLeave() GameTooltip:Hide() end

local function getPin(name)
    local pin = pins[name]
    if pin then return pin end
    pin = CreateFrame("Frame", nil, canvas)
    pin:SetSize(PIN_SIZE, PIN_SIZE)
    pin:SetFrameLevel(pinLevel())
    pin.tex = pin:CreateTexture(nil, "OVERLAY")
    pin.tex:SetAllPoints()
    pin.tex:SetTexture(TEXTURE)
    pin.who = name
    pin:EnableMouse(true)
    -- el clic sigue llegando al mapa, para poder cambiar de zona pinchando encima
    if pin.SetMouseClickEnabled then pin:SetMouseClickEnabled(false) end
    pin:SetScript("OnEnter", pinEnter)
    pin:SetScript("OnLeave", pinLeave)
    pin:Hide()
    pins[name] = pin
    return pin
end

-- La marca mide siempre lo mismo, aunque se acerque el mapa
local function place(pin)
    local scale = 1 / canvasScale()
    pin:SetScale(scale)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", canvas:GetWidth() * pin.nx / scale, -canvas:GetHeight() * pin.ny / scale)
end

local function refreshPin(name)
    if not canvas then return end
    local p = positions[name]
    local shown = opened and p and WorldMapFrame:GetMapID()
    local nx, ny
    if shown then nx, ny = project(p.m, p.x / PRECISION, p.y / PRECISION, shown) end
    if not nx or nx < 0 or nx > 1 or ny < 0 or ny > 1 then
        if pins[name] then pins[name]:Hide() end
        return
    end
    local pin = getPin(name)
    if not pin.class then
        pin.class = SG:ClassOf(name)
        pin.tex:SetVertexColor(SG:ClassRGB(pin.class))
    end
    pin.nx, pin.ny = nx, ny
    place(pin)
    pin:Show()
end

local function refreshAll()
    for name, pin in pairs(pins) do
        if not positions[name] then pin:Hide() end
    end
    for name in pairs(positions) do refreshPin(name) end
end

local function placeAll()
    if not canvas then return end
    for _, pin in pairs(pins) do
        if pin:IsShown() then place(pin) end
    end
end

-- Quita a quien ya no da noticias (se ha desconectado, o entrado en una instancia en combate...)
local function expire()
    local now = GetTime()
    for name, p in pairs(positions) do
        local r = SG.roster[name]
        if now - p.t >= EXPIRE or (r and not r.online) then
            positions[name] = nil
            refreshPin(name)
        end
    end
end

local function ask()
    local now = GetTime()
    if lastAsk and now - lastAsk < ASK_MIN then return end
    lastAsk = now
    Comm:Send({ t = "MAP_ON" }, "GUILD")
end

local function viewTick()
    if lastAsk and GetTime() - lastAsk >= ASK_EVERY then ask() end
    expire()
end

local function openMap()
    if opened or not isOn() then return end
    opened = true
    ask()
    viewTicker = C_Timer.NewTicker(VIEW_EVERY, function() SG:Try(viewTick) end)
    expire()
    refreshAll()
end

local function closeMap()
    if not opened then return end
    opened = false
    if viewTicker then viewTicker:Cancel() end
    viewTicker = nil
    for _, pin in pairs(pins) do pin:Hide() end
end

Comm:Register("POS", function(msg, sender, channel)
    if not opened or channel ~= "GUILD" then return end
    if type(msg.m) == "number" and type(msg.x) == "number" and type(msg.y) == "number" then
        local p = positions[sender]
        if not p then
            p = {}
            positions[sender] = p
        end
        p.m, p.x, p.y, p.t = msg.m, msg.x, msg.y, GetTime()
    else
        positions[sender] = nil
    end
    refreshPin(sender)
end)

SG:Listen("SETTINGS_CHANGED", function()
    if not provider then return end
    closeMap()
    if WorldMapFrame:IsShown() then openMap() end
end)

---------------------------------------------------------------------------
-- Enganche con el mapa del juego
---------------------------------------------------------------------------
local function attach()
    if provider then return end
    if not (WorldMapFrame and WorldMapFrame.AddDataProvider and WorldMapFrame.GetCanvas
        and MapCanvasDataProviderMixin and CreateFromMixins) then return end
    provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:OnShow() SG:Try(openMap) end
    function provider:OnHide() SG:Try(closeMap) end
    function provider:RefreshAllData() SG:Try(refreshAll) end
    function provider:OnMapChanged() SG:Try(refreshAll) end
    function provider:OnCanvasScaleChanged() SG:Try(placeAll) end
    function provider:OnCanvasSizeChanged() SG:Try(placeAll) end
    canvas = WorldMapFrame:GetCanvas()
    WorldMapFrame:AddDataProvider(provider)
    if WorldMapFrame:IsShown() then openMap() end
end

function M:OnLogin() attach() end

-- por si el mapa del juego se carga más tarde que el addon
SG:On("ADDON_LOADED", function(name)
    if name == "Blizzard_WorldMap" then attach() end
end)
