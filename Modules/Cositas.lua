-- SolfaGuild - Cositas: estadísticas tontas por personaje (peces, saltos, muertes...).
-- Las categorías (títulos y descripciones) están en Texts.cositas.
--
-- Rendimiento: casi todo sale de eventos raros o de enganches a funciones
-- (saltar, /roll, emotes...). Lo único que corre a menudo es el registro de
-- combate (curación, bufos, resurrecciones, jabalíes y caídas): tiene su propio
-- marco y lo primero que hace es comparar el GUID de origen/destino con el
-- tuyo, así que lo que no sea tuyo se descarta sin más trabajo.
-- Los contadores no fuerzan envíos: viajan con el perfil, que sale cada minuto si ha cambiado.
--
-- En Forever no hay registro de combate (ver la sección "Forever"):
-- Paracaidista, por el resumen de muerte. Colegón y Ángel de la guarda, por los
-- hechizos que lanzas. P.E.T.A., por la línea de experiencia. Sorakambulancia, por el
-- medidor de daño del propio juego (C_DamageMeter, lo mismo que usa Details).

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
local BOAR_NAMES = { "jaba", "boar" }
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

-- Solo la caída: ahogarse, la fatiga o la lava no cuentan
local function fellToDeath()
    local best = SG:LastRecap()
    local env = best and SG:Open(best.environmentalType)
    return env ~= nil and tostring(env):lower() == "falling"
end

local lastDeath = -math.huge
SG:On("PLAYER_DEAD", function()
    -- en Forever el juego repite el evento al liberar el espíritu
    local now = GetTime()
    if now - lastDeath < 30 then return end
    lastDeath = now
    add("deaths")
    if inGroup() and not groupMateDead() then add("leeroy") end
    if SG.HasCombatLog then
        if now - lastFall < 2 then add("falls") end
    else
        C_Timer.After(1, function()
            if fellToDeath() then add("falls") end
        end)
    end
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

---------------------------------------------------------------------------
-- Forever: Colegón y Ángel de la guarda, por los hechizos que lanzas a otros
---------------------------------------------------------------------------
-- Primer rango de cada hechizo: los demás rangos se llaman igual y se compara por nombre
local BUFF_SPELLS = {
    1243, 14752, 976, 17, 6346, 10060, 1706,                -- sacerdote
    21562, 27681, 27683,                                    -- sacerdote, de grupo
    1459, 1008, 604, 23028,                                 -- mago
    1126, 467, 29166, 21849,                                -- druida
    19740, 19742, 20217, 1038, 19977, 20911, 1044, 1022, 6940,   -- paladín
    25782, 25894, 25898, 25895, 25890, 25899,               -- paladín, superiores
    5697, 132, 11743,                                       -- brujo
    131, 546,                                               -- chamán
}
local REZ_SPELLS = { 2006, 7328, 2008, 20484 }
local BUFF_REPEAT = 300     -- s sin volver a contar el mismo bufo al mismo jugador
local REZ_FORGET = 600      -- s sin volver a contar a quien sigue muerto y no se puede ver

local spellKind             -- [nombre del hechizo] = "buff" o "rez"
local casts = {}            -- [identificador del lanzamiento] = { kind, spell, target, t }
local buffed, rezzed = {}, {}   -- [hechizo|jugador] y [jugador] = GetTime()

local function buildSpellKinds()
    spellKind = {}
    for _, id in ipairs(BUFF_SPELLS) do
        local n = spellName(id)
        if n then spellKind[n] = "buff" end
    end
    for _, id in ipairs(REZ_SPELLS) do
        local n = spellName(id)
        if n then spellKind[n] = "rez" end
    end
end

local function onCastSent(target, castGUID, spellID)
    target, spellID = SG:Open(target), SG:Open(spellID)
    if not spellKind or not spellID or not castGUID or type(target) ~= "string" or target == "" then return end
    local spell = spellName(spellID)
    local kind = spell and spellKind[spell]
    if not kind then return end
    target = SG:Short(target)
    if target == SG:MyName() or target == (UnitName("player")) then return end
    -- a mascotas y criaturas no; solo se puede saber si lo tienes de objetivo
    if SG:UnitFull("target") == target and not SG:Open(UnitIsPlayer("target")) then return end
    casts[castGUID] = { kind = kind, spell = spell, target = target, t = GetTime() }
end

local function onCastDone(castGUID)
    local c = castGUID and casts[castGUID]
    if not c then return end
    casts[castGUID] = nil
    local now = GetTime()
    if c.kind == "buff" then
        local k = c.spell .. "|" .. c.target
        -- repetirlo renueva la espera: quien lo spamea no suma nunca
        if not buffed[k] or now - buffed[k] >= BUFF_REPEAT then add("buffs") end
        buffed[k] = now
    elseif not rezzed[c.target] then
        add("rez")
        rezzed[c.target] = now
    end
end

-- Quien ya estaba resucitado y sigue muerto (aceptando o ausente) no vuelve a contar
-- hasta que se le vea vivo. Si no va en tu grupo ni es tu objetivo, se olvida con el tiempo.
local function forgetRezzed(now)
    for name, t in pairs(rezzed) do
        local unit = SG:GroupUnit(name) or (SG:UnitFull("target") == name and "target") or nil
        if now - t > REZ_FORGET or (unit and SG:Open(UnitIsDeadOrGhost(unit)) == false) then
            rezzed[name] = nil
        end
    end
    for k, t in pairs(buffed) do
        if now - t > BUFF_REPEAT then buffed[k] = nil end
    end
    for k, c in pairs(casts) do
        if now - c.t > 60 then casts[k] = nil end
    end
end

---------------------------------------------------------------------------
-- Forever: P.E.T.A., por la línea de experiencia ("Jabalí muere, ganas 12...")
---------------------------------------------------------------------------
local function xpPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    fmt = fmt:gsub("%%%d%$([sd])", "%%%1")
    local middle = fmt:match("^%%s(.-)%%d")
    if not middle then return nil end
    return "^(.-)" .. middle:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
end

local XP_LINE = xpPattern(COMBATLOG_XPGAIN_FIRSTPERSON)

if not SG.HasCombatLog then
    SG:On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
        msg = SG:Open(msg)
        if not XP_LINE or type(msg) ~= "string" then return end
        if isBoar(msg:match(XP_LINE)) then add("boars") end
    end)
end

---------------------------------------------------------------------------
-- Forever: Sorakambulancia, por el medidor del propio juego. Los valores están ocultos
-- en combate, así que se lee al salir, y de cada sesión solo se suma lo nuevo.
---------------------------------------------------------------------------
local healSeen             -- [sesión] = curación ya sumada (nil hasta la primera lectura)

local function readHealing(baseline)
    local DM = C_DamageMeter
    if not (DM and DM.GetAvailableCombatSessions and DM.GetCombatSessionFromID) or SG:InCombat() then return end
    local healType = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.HealingDone) or 2
    for _, s in ipairs(DM.GetAvailableCombatSessions() or {}) do
        local id = SG:Open(s.sessionID)
        local session = id and DM.GetCombatSessionFromID(id, healType)
        local sources = session and SG:Open(session.combatSources)
        for _, src in ipairs(type(sources) == "table" and sources or {}) do
            if SG:Open(src.isLocalPlayer) then
                local total = SG:Open(src.totalAmount)
                if type(total) == "number" then
                    if not baseline and total > (healSeen[id] or 0) then add("heal", total - (healSeen[id] or 0)) end
                    healSeen[id] = total
                end
                break
            end
        end
    end
end

if not SG.HasCombatLog and C_DamageMeter then
    SG:On("PLAYER_REGEN_ENABLED", function()
        C_Timer.After(3, function() if healSeen then SG:Try(readHealing) end end)
    end)
    SG:On("DAMAGE_METER_COMBAT_SESSION_UPDATED", function()
        if healSeen and not SG:InCombat() then SG:Try(readHealing) end
    end)
    SG:On("DAMAGE_METER_RESET", function()
        if healSeen then wipe(healSeen) end
    end)
end

local herbName
local spells = CreateFrame("Frame")
spells:SetScript("OnEvent", function(_, event, unit, a, b, c)
    if unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_SENT" then
        onCastSent(a, b, c)       -- objetivo, identificador del lanzamiento, hechizo
        return
    end
    onCastDone(a)                 -- identificador del lanzamiento, hechizo
    if herbName and b and spellName(b) == herbName then add("herbs") end
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
    if not SG.HasCombatLog then forgetRezzed(GetTime()) end
    if not afk and IsSwimming() then add("swim", TICK) end
    local zoneInfo = (C_PvP and C_PvP.GetZonePVPInfo) or GetZonePVPInfo
    if not afk and zoneInfo and zoneInfo() == "hostile" then add("enemyLand", TICK) end
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

    if SG.HasCombatLog then cl:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end
    if spells.RegisterUnitEvent then
        spells:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    else
        spells:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    end
    if not SG.HasCombatLog then
        buildSpellKinds()
        spells:RegisterEvent("UNIT_SPELLCAST_SENT")
        -- lo que el medidor ya tenía al entrar (tras un /reload) no se vuelve a sumar
        C_Timer.After(2, function()
            healSeen = {}
            SG:Try(readHealing, true)
        end)
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
