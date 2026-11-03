-- SolfaGuild - Cositas: estadísticas tontas por personaje (peces, saltos, muertes...).
-- Las categorías (títulos y descripciones) están en Texts.cositas.
--
-- Rendimiento: casi todo sale de eventos raros o de enganches a funciones
-- (saltar, /roll, emotes...). Lo único que corre a menudo es el registro de
-- combate (curación, bufos, resurrecciones, jabalíes y caídas): tiene su propio
-- marco y lo primero que hace es comparar el GUID de origen/destino con el
-- tuyo, así que lo que no sea tuyo se descarta sin más trabajo.
-- Los contadores no fuerzan envíos: viajan con el latido de 5 min del perfil.

local _, ns = ...
local SG = ns.SG

local Cos = SG:RegisterModule("Cositas", {})
SG.Cositas = Cos

local band = bit.band
local TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
local LOOT_NEED = 1
-- segundos entre muestras de los contadores de tiempo; impar a propósito para
-- que los tiempos no salgan siempre múltiplos de 5 y haya menos empates
local TICK = 3
local SESSION_GAP = 180        -- si pasa menos que esto entre muestras (un /reload) la sesión sigue

-- emotes que cuentan para "Sobón"
local CUDDLY = { HUG = true, KISS = true, PET = true, CUDDLE = true, TICKLE = true, LOVE = true, FLIRT = true }
-- nombres de jabalí (cliente en español o en inglés)
local BOAR_NAMES = { "jabal", "boar" }
local HERB_SPELL = 2366        -- Recoger hierbas (todos los rangos se llaman igual)

local stats       -- SG:MyChar().cositas (nil hasta entrar al juego)
local enabled = true
local myGUID
local lastFall, lastFish = 0, 0

local function add(key, n)
    if not stats or not enabled then return end
    stats[key] = (stats[key] or 0) + (n or 1)
end

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end

-- Convierte un texto del juego ("Creas: %s.") en patrón de búsqueda. Así
-- funciona en cualquier idioma: el propio juego da el texto en el del cliente.
local function toPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    fmt = fmt:gsub("%%%d%$([sd])", "%%%1")                      -- "%1$s" -> "%s"
    fmt = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    fmt = fmt:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. fmt .. "$"
end

local CREATED_MULTI = toPattern(LOOT_ITEM_CREATED_SELF_MULTIPLE)
local CREATED       = toPattern(LOOT_ITEM_CREATED_SELF)
local AUCTION_WON   = toPattern(ERR_AUCTION_WON_S)

---------------------------------------------------------------------------
-- Registro de combate (solo lo tuyo)
---------------------------------------------------------------------------
local function isBoar(name)
    if not name then return false end
    name = name:lower()
    for _, b in ipairs(BOAR_NAMES) do
        if name:find(b, 1, true) then return true end
    end
    return false
end

local function fromMe(sub, destName, destFlags, a15, a16)
    local toPlayer = band(destFlags or 0, TYPE_PLAYER) > 0
    if sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then
        local effective = (a15 or 0) - (a16 or 0)     -- curado - sobrecuración
        if toPlayer and effective > 0 then add("heal", effective) end
    elseif sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
        if toPlayer and a15 == "BUFF" then add("buffs") end
    elseif sub == "SPELL_RESURRECT" then
        if toPlayer then add("rez") end
    elseif sub == "PARTY_KILL" then
        if isBoar(destName) then add("boars") end
    end
end

local cl = CreateFrame("Frame")
cl:SetScript("OnEvent", function()
    if not stats or not enabled then return end
    local _, sub, _, src, _, _, _, dest, destName, destFlags, _, a12, _, _, a15, a16 = CombatLogGetCurrentEventInfo()
    if src == myGUID then
        if dest ~= myGUID then fromMe(sub, destName, destFlags, a15, a16) end
    elseif dest == myGUID then
        if sub == "ENVIRONMENTAL_DAMAGE" and type(a12) == "string" and a12:upper() == "FALLING" then
            lastFall = GetTime()
        end
    elseif sub == "PARTY_KILL" and src and src == UnitGUID("pet") then
        if isBoar(destName) then add("boars") end
    end
end)

---------------------------------------------------------------------------
-- Muertes
---------------------------------------------------------------------------
-- ¿Hay alguien más del grupo ya muerto?
local function groupMateDead()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    local prefix = (IsInRaid and IsInRaid()) and "raid" or "party"
    for i = 1, n do
        local u = prefix .. i
        if UnitExists(u) and not UnitIsUnit(u, "player") and UnitIsDeadOrGhost(u) then return true end
    end
    return false
end

local function inGroup()
    if IsInGroup then return IsInGroup() end
    return (GetNumGroupMembers and GetNumGroupMembers() or 0) > 0
end

SG:On("PLAYER_DEAD", function()
    add("deaths")
    if GetTime() - lastFall < 2 then add("falls") end
    if inGroup() and not groupMateDead() then add("leeroy") end
end)

---------------------------------------------------------------------------
-- Eventos sueltos
---------------------------------------------------------------------------
SG:On("LOOT_OPENED", function()
    if IsFishingLoot and IsFishingLoot() and GetTime() - lastFish > 1 then
        lastFish = GetTime()
        add("fish")
    end
end)

SG:On("MAIL_SEND_SUCCESS", function() add("mail") end)

SG:On("CHAT_MSG_LOOT", function(msg)
    if not msg then return end
    local _, n = nil, nil
    if CREATED_MULTI then _, n = msg:match(CREATED_MULTI) end
    if n then add("crafted", tonumber(n) or 1)
    elseif CREATED and msg:match(CREATED) then add("crafted") end
end)

SG:On("CHAT_MSG_SYSTEM", function(msg)
    if AUCTION_WON and msg and msg:match(AUCTION_WON) then add("ah") end
end)

local herbName
local spells = CreateFrame("Frame")
spells:SetScript("OnEvent", function(_, _, unit, _, spellID)
    if unit ~= "player" or not herbName or not spellID then return end
    if spellName(spellID) == herbName then add("herbs") end
end)

-- La peluquería no existe en Classic Era: si el evento no existe, no se registra
local barber = CreateFrame("Frame")
pcall(barber.RegisterEvent, barber, "BARBER_SHOP_APPEARANCE_APPLIED")
barber:SetScript("OnEvent", function() add("barber") end)

---------------------------------------------------------------------------
-- Contadores de tiempo y sesión
---------------------------------------------------------------------------
local function tick()
    if not stats then return end
    local c = SG:MyChar()
    local now = time()
    -- sesión: un /reload no la corta (la muestra anterior es de hace poco)
    if not c.sessionStart or now - (c.sessionSeen or 0) > SESSION_GAP then c.sessionStart = now end
    c.sessionSeen = now
    if not enabled then return end
    local len = now - c.sessionStart
    if len > (stats.session or 0) then stats.session = len end

    local afk = UnitIsAFK("player")
    if not afk and IsSwimming() then add("swim", TICK) end
    if not afk and GetZonePVPInfo and GetZonePVPInfo() == "hostile" then add("enemyLand", TICK) end
    if UnitIsGhost("player") then add("ghost", TICK) end
    if inGroup() then add("group", TICK) end
end

---------------------------------------------------------------------------
-- Enganches a funciones del juego (solo si existen en este cliente)
---------------------------------------------------------------------------
local function hook(name, fn)
    if type(_G[name]) == "function" then hooksecurefunc(name, fn) end
end

local function refreshEnabled() enabled = SG:Feature("cositas") end
SG:Listen("SETTINGS_CHANGED", refreshEnabled)

function Cos:OnLogin()
    local c = SG:MyChar()
    c.cositas = c.cositas or {}
    stats = c.cositas
    myGUID = UnitGUID("player")
    herbName = spellName(HERB_SPELL)
    refreshEnabled()

    cl:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    if spells.RegisterUnitEvent then
        spells:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    else
        spells:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    end

    hook("JumpOrAscendStart", function()
        if not IsSwimming() and not (IsFlying and IsFlying()) then add("jumps") end
    end)
    hook("RandomRoll", function() add("rolls") end)
    hook("RollOnLoot", function(_, rollType) if rollType == LOOT_NEED then add("need") end end)
    hook("ConfirmTalentWipe", function() add("respec") end)
    hook("InspectUnit", function(unit)
        if unit and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then add("inspect") end
    end)
    hook("DoEmote", function(token)
        if type(token) == "string" and CUDDLY[token:upper()] then add("hugs") end
    end)

    tick()
    C_Timer.NewTicker(TICK, function() SG:Try(tick) end)
end

---------------------------------------------------------------------------
-- Consultas para la ventana
---------------------------------------------------------------------------
-- Valor de una categoría para una cuenta (suma de sus personajes; la sesión
-- más larga es la mayor de todos ellos)
function Cos:Value(acc, key)
    if key == "played" or key == "earned" then return SG:AccountSum(acc, key) end
    local total = 0
    for _, c in pairs(acc.chars or {}) do
        local v = type(c.cositas) == "table" and tonumber(c.cositas[key]) or 0
        if key == "session" then
            if v > total then total = v end
        else
            total = total + v
        end
    end
    return total
end

-- Lista de categorías con el mejor de cada una y tu valor
function Cos:Board()
    local accounts = SG:Accounts()
    local out = {}
    for _, cat in ipairs(SG.Texts.cositas) do
        local best, mine = nil, 0
        for _, acc in pairs(accounts) do
            local v = self:Value(acc, cat.key)
            if acc.mine then mine = v end
            if v > 0 and (not best or v > best.value) then best = { acc = acc, value = v } end
        end
        out[#out + 1] = { cat = cat, best = best, mine = mine }
    end
    return out
end
