-- SolfaGuild - Jugadores: main/alters, roster, perfiles y sincronización.
-- Cada cuenta (= jugador) tiene un id aleatorio guardado en SavedVariables.
-- Como los SavedVariables son por cuenta, todos los personajes logueados con
-- el addon en esa cuenta quedan agrupados automáticamente como alters.

local _, ns = ...
local SG = ns.SG
local Comm = SG.Comm

local P = SG:RegisterModule("Players", {})
SG.Players = P

SG.roster = {}          -- [nombre] = { rankIndex, rank, level, class, zone, online }
SG.addonOnline = {}     -- [nombre] = GetTime() último mensaje
SG.gmName = nil

---------------------------------------------------------------------------
-- Roster de la guild
---------------------------------------------------------------------------
function SG:RequestRoster()
    if not IsInGuild() then return end
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local function readRoster()
    if not IsInGuild() then return end
    local roster = {}
    local n = GetNumGuildMembers()
    for i = 1, n do
        local name, rank, rankIndex, level, _, zone, _, _, online, _, classFile = GetGuildRosterInfo(i)
        if name then
            local full = name
            name = SG:Short(name)
            roster[name] = {
                full = full, rank = rank, rankIndex = rankIndex, level = level,
                class = classFile, zone = zone, online = online and true or false,
            }
            if rankIndex == 0 then SG.gmName = name end
        end
    end
    SG.roster = roster
    -- con los desconectados ocultos, o sin haber cargado aún, no se sabe quién falta
    SG.rosterFull = roster[SG:MyName()] ~= nil
        and (not GetGuildRosterShowOffline or GetGuildRosterShowOffline()) and true or false
    -- quien se desconecta ya no tiene el addon "online"
    for name in pairs(SG.addonOnline) do
        if roster[name] and not roster[name].online then SG.addonOnline[name] = nil end
    end
    local me = roster[SG:MyName()]
    if me then
        local gdb = SG:GuildDB()
        if gdb and me.rankIndex == 0 then
            gdb.gmAccount = SG.db.accountId
            SG.db.my.isGMAccount[SG:GuildName()] = true
        end
    end
    SG:Fire("ROSTER_UPDATED")
end

SG:On("GUILD_ROSTER_UPDATE", function() readRoster() end)

function SG:IsGuildMember(name)
    name = SG:Short(name)
    return name and SG.roster[name] ~= nil
end

function SG:MyRankIndex()
    local me = SG.roster[SG:MyName()]
    return me and me.rankIndex or 99
end

---------------------------------------------------------------------------
-- Perfil propio
---------------------------------------------------------------------------
local function topN(t, n)
    local arr = {}
    for k, v in pairs(t or {}) do arr[#arr + 1] = { k, v } end
    table.sort(arr, function(a, b) return a[2] > b[2] end)
    local out = {}
    for i = 1, math.min(n, #arr) do out[arr[i][1]] = arr[i][2] end
    return out
end

-- loggingOut: al salir, GetGuildInfo() puede devolver nil, así que no tocamos
-- la guild guardada.
function SG:RefreshMyChar(loggingOut)
    local c = self:MyChar()
    c.level = UnitLevel("player")
    c.class = select(2, UnitClass("player"))
    if self.Playtime then self.Playtime:Update() end
    if loggingOut then return c end
    c.guild = self:GuildName()
    c.gold = nil   -- de versiones anteriores: el oro actual ya no se guarda
    c.partners = nil  -- de versiones anteriores: ahora son "teams"
    self:CheckWeek(c)
    return c
end

-- Nueva semana: reinicia los contadores semanales del personaje
function SG:CheckWeek(c)
    local wk = self:WeekKey()
    if c.weekKey ~= wk then
        c.weekKey = wk; c.killsWeek = 0; c.dungeonsWeek = 0; c.zonesWeek = {}; c.teamsWeek = {}
        c.dgWeek = {}; c.dgTeamsWeek = {}
    end
end

-- Personajes de mi cuenta que están en la guild actual. El juego no da la lista de
-- personajes de la cuenta: uno borrado se nota porque ya no sale en la guild. Solo se
-- deja de contar, sin tocar sus datos, y al enviar el perfil los demás también lo pierden.
function SG:MyGuildChars()
    local g, me = self:GuildName(), self:MyName()
    local out = {}
    for name, c in pairs(self.db.my.chars) do
        if name == me or (c.guild == g and not (self.rosterFull and not self.roster[name])) then
            out[name] = c
        end
    end
    return out
end

-- public: perfil para enviar a la guild. El oro acumulado solo viaja como
-- total de la cuenta (earned); el de cada personaje no sale de este PC.
function SG:BuildMyProfile(public)
    self:RefreshMyChar()
    local chars = {}
    local earned = 0
    for name, c in pairs(self:MyGuildChars()) do
        earned = earned + (tonumber(c.earned) or 0)
        chars[name] = {
            class = c.class, level = c.level,
            kills = c.kills, killsWeek = c.killsWeek, dungeonsWeek = c.dungeonsWeek, weekKey = c.weekKey,
            earned = (not public) and c.earned or nil,
            played = c.played,
            cositas = c.cositas,
            dungeons = c.dungeons, zones = c.zones, zonesWeek = c.zonesWeek,
            teams = topN(c.teams, 15), teamsWeek = topN(c.teamsWeek, 15),
            dgWeek = c.dgWeek, dgTeams = topN(c.dgTeams, 40), dgTeamsWeek = topN(c.dgTeamsWeek, 40),
        }
    end
    local main = self.db.my.main
    if not chars[main] then main = self:MyName() end
    return {
        id = self.db.accountId,
        main = main,
        chars = chars,
        earned = earned,
        updated = self:Now(),
        milestones = self.db.my.milestones,
        v = self.version,
    }
end

-- Cuenta propia en el mismo formato que las cacheadas
function SG:MyAccount()
    local p = self:BuildMyProfile()
    p.mine = true
    return p
end

---------------------------------------------------------------------------
-- Cuentas conocidas
---------------------------------------------------------------------------
function SG:Accounts()
    local gdb = self:GuildDB()
    local list = {}
    local mine = self:MyAccount()
    list[mine.id] = mine   -- tú siempre sales, aunque no tengas guild
    if not gdb then return list end
    -- índice para resolver personajes reclamados por varias cuentas (gana el más reciente)
    local owner = {}
    for name in pairs(mine.chars) do owner[name] = { id = mine.id, u = math.huge } end
    for id, acc in pairs(gdb.accounts) do
        if id ~= mine.id then
            for name in pairs(acc.chars or {}) do
                local o = owner[name]
                if not o or (acc.updated or 0) > o.u then owner[name] = { id = id, u = acc.updated or 0 } end
            end
        end
    end
    for id, acc in pairs(gdb.accounts) do
        if id ~= mine.id then
            local copy = { id = id, main = acc.main, updated = acc.updated, chars = {}, milestones = acc.milestones,
                earned = acc.earned }
            for name, c in pairs(acc.chars or {}) do
                if owner[name] and owner[name].id == id then copy.chars[name] = c end
            end
            if next(copy.chars) then list[id] = copy end
        end
    end
    return list
end

function SG:AccountOf(charName)
    charName = self:Short(charName)
    for id, acc in pairs(self:Accounts()) do
        if acc.chars[charName] then return acc end
    end
end

function SG:MainOf(charName)
    local acc = self:AccountOf(charName)
    return acc and acc.main or self:Short(charName)
end

-- Clase de un personaje (perfil o roster)
function SG:ClassOf(name, acc)
    acc = acc or self:AccountOf(name)
    if acc and acc.chars[name] and acc.chars[name].class then return acc.chars[name].class end
    local r = self.roster[name]
    return r and r.class
end

function SG:ColoredMain(acc)
    local main = acc.main
    return self:ClassColor(self:ClassOf(main, acc)) .. main .. "|r"
end

-- Suma un campo de todos los personajes de una cuenta. Si la cuenta trae el
-- total ya hecho (oro de otros jugadores), se usa ese.
function SG:AccountSum(acc, field)
    if type(acc[field]) == "number" then return acc[field] end
    local total = 0
    for _, c in pairs(acc.chars or {}) do total = total + (tonumber(c[field]) or 0) end
    return total
end

function SG:AccountWeekKills(acc)
    local wk, total = self:WeekKey(), 0
    for _, c in pairs(acc.chars or {}) do
        if c.weekKey == wk then total = total + (c.killsWeek or 0) end
    end
    return total
end

function SG:AccountWeekDungeons(acc)
    local wk, total = self:WeekKey(), 0
    for _, c in pairs(acc.chars or {}) do
        if c.weekKey == wk then total = total + (c.dungeonsWeek or 0) end
    end
    return total
end

function SG:AccountDungeons(acc)
    local total = 0
    for _, c in pairs(acc.chars or {}) do
        for _, n in pairs(c.dungeons or {}) do total = total + n end
    end
    return total
end

-- Ranking genérico: devuelve lista ordenada { acc, value }
function SG:Ranking(valueFn)
    local out = {}
    for _, acc in pairs(self:Accounts()) do
        local v = valueFn(acc)
        -- los demás solo salen si tienen algo; tú siempre, para que veas dónde estás
        if v and (v > 0 or acc.mine) then out[#out + 1] = { acc = acc, value = v or 0 } end
    end
    -- si empatan, por nombre: así todos ven el mismo orden y los mismos rangos
    table.sort(out, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return (a.acc.main or "") < (b.acc.main or "")
    end)
    return out
end

-- Escalafón: los jugadores (ya ordenados, de SG:Ranking) llenan los rangos en
-- orden. Devuelve { { name, members = { {acc, value} } } } solo con rangos
-- ocupados, y aparte tu cuenta si aún está a cero.
function SG:BuildLadder(list, tiers)
    local out, idx = {}, 1
    for _, tier in ipairs(tiers) do
        local members = {}
        while list[idx] and (list[idx].value > 0 or tier.zero) and (not tier.players or #members < tier.players) do
            members[#members + 1] = list[idx]
            idx = idx + 1
        end
        if #members > 0 then out[#out + 1] = { name = self:Fmt(tier.name), members = members } end
    end
    local nobody
    for i = idx, #list do
        if list[i].acc.mine then nobody = list[i] end
    end
    return out, nobody
end

-- Rango de una cuenta en un escalafón (nil = está a cero)
function SG:LadderRankOf(ladder, acc)
    for _, tier in ipairs(ladder) do
        for _, it in ipairs(tier.members) do
            if it.acc.id == acc.id then return tier.name end
        end
    end
end

---------------------------------------------------------------------------
-- Sincronización
---------------------------------------------------------------------------
local dirty = false
function SG:MarkDirty() dirty = true end

-- Para saber si el perfil ha cambiado. El tiempo jugado no cuenta: cambia siempre.
local sentKey
local function profileKey(p)
    local updated, played = p.updated, {}
    p.updated = nil
    for name, c in pairs(p.chars) do played[name], c.played = c.played, nil end
    local key = Comm:Serialize(p)
    p.updated = updated
    for name, c in pairs(p.chars) do c.played = played[name] end
    return key
end

function SG:BroadcastProfile(channel, target)
    -- recuperando datos: no enviamos una cuenta nueva a cero que tape a la buena
    if not IsInGuild() or self.restoring then return end
    local p = self:BuildMyProfile(true)
    local guild = not channel or channel == "GUILD"
    if guild then sentKey = profileKey(p) end
    p.t = "PROF"
    Comm:Send(p, channel or "GUILD", target)
    if guild then dirty = false end
end

local function storeAccount(p, sender)
    local gdb = SG:GuildDB()
    if not gdb or type(p.id) ~= "string" or type(p.chars) ~= "table" then return false end
    if p.id == SG.db.accountId then return false end
    local old = gdb.accounts[p.id]
    if old and (old.updated or 0) >= (p.updated or 0) then return false end
    -- del oro solo guardamos el total acumulado, aunque alguien envíe el de cada personaje
    for _, c in pairs(p.chars) do
        if type(c) == "table" then c.gold, c.earned = nil, nil end
    end
    gdb.accounts[p.id] = { main = p.main, chars = p.chars, updated = p.updated, milestones = p.milestones,
        earned = tonumber(p.earned) }
    for name in pairs(p.chars) do gdb.seen[name] = gdb.seen[name] or p.updated end
    -- el GM solo se reconoce si el perfil lo envía el propio GM
    if sender and SG.gmName and sender == SG.gmName and p.chars[sender] then
        gdb.gmAccount = p.id
    end
    return true
end

---------------------------------------------------------------------------
-- Recuperación: si este PC empieza con los datos vacíos (WTF borrado), el
-- HELLO lleva "fresh" y quien tenga la cuenta de este personaje se la manda
-- (RELAY). Se adopta la cuenta (id, main, personajes, oro, hitos) y se le
-- suma lo hecho desde que se entró. El juego garantiza quién envía cada
-- mensaje, así que solo puede recuperar una cuenta quien juega uno de sus
-- personajes.
-- Si en RESTORE_WINDOW no llega nada (nadie conectado), se sigue como cuenta
-- nueva pero la recuperación queda pendiente (db.my.restorePending) durante
-- RESTORE_DAYS: en cada entrada se vuelve a pedir y, si llega, se juntan las
-- dos. "/sg recuperar" la vuelve a pedir a mano.
---------------------------------------------------------------------------
local RESTORE_WINDOW = 30   -- segundos tras entrar esperando la cuenta antigua
local RESTORE_DAYS = 60     -- días que se sigue intentando

local function addTo(dst, src)
    for k, v in pairs(type(src) == "table" and src or {}) do
        if type(v) == "number" then dst[k] = (dst[k] or 0) + v end
    end
end

local function n(v) return tonumber(v) or 0 end

local function restoreFrom(p)
    local db, me, wk, g = SG.db, SG:MyName(), SG:WeekKey(), SG:GuildName()
    SG.restoring = false
    db.my.restorePending = nil
    -- la cuenta provisional queda en la guild con lo mismo que ya llevamos: no se recupera nunca
    db.my.formerIds = db.my.formerIds or {}
    db.my.formerIds[db.accountId] = true
    db.accountId = p.id
    if type(p.main) == "string" then db.my.main = p.main end
    for k, v in pairs(type(p.milestones) == "table" and p.milestones or {}) do
        if db.my.milestones[k] == nil then db.my.milestones[k] = v end
    end
    for name, old in pairs(p.chars) do
        if type(old) == "table" then
            local c = db.my.chars[name] or {}
            db.my.chars[name] = c
            c.class = c.class or old.class
            c.level = math.max(n(c.level), n(old.level))
            c.guild = c.guild or g
            c.played = math.max(n(c.played), n(old.played))
            c.kills = n(c.kills) + n(old.kills)
            for _, f in ipairs({ "zones", "teams", "dungeons", "dgTeams" }) do
                c[f] = c[f] or {}
                addTo(c[f], old[f])
            end
            -- se conserva la misma tabla: Cositas la tiene apuntada
            c.cositas = c.cositas or {}
            local session = math.max(n(c.cositas.session), n(type(old.cositas) == "table" and old.cositas.session))
            addTo(c.cositas, old.cositas)
            c.cositas.session = session
            SG:CheckWeek(c)
            if old.weekKey == wk then
                c.killsWeek = n(c.killsWeek) + n(old.killsWeek)
                c.dungeonsWeek = n(c.dungeonsWeek) + n(old.dungeonsWeek)
                c.zonesWeek = c.zonesWeek or {}; addTo(c.zonesWeek, old.zonesWeek)
                c.teamsWeek = c.teamsWeek or {}; addTo(c.teamsWeek, old.teamsWeek)
                c.dgWeek = c.dgWeek or {}; addTo(c.dgWeek, old.dgWeek)
                c.dgTeamsWeek = c.dgTeamsWeek or {}; addTo(c.dgTeamsWeek, old.dgTeamsWeek)
            end
            -- del oro solo viaja el total de la cuenta (va a este personaje); a
            -- cada uno se le quita el oro que llevaba encima al empezar de cero
            c.earned = math.max(0, n(c.earned) - n(c.seededWith))
            c.seededWith = nil
            c.goldSeeded = true
        end
    end
    local c = db.my.chars[me]
    c.earned = n(c.earned) + n(p.earned)
    local gdb = SG:GuildDB()
    if gdb then gdb.accounts[p.id] = nil end
    SG:Print("Datos recuperados de la guild: vuelves a ser " .. tostring(db.my.main) .. ".")
    SG:Fire("RESTORE_DONE")
    SG:MarkDirty()
    SG:BroadcastProfile()
    SG:Fire("DATA_UPDATED")
end

-- Cuenta guardada que contiene a este personaje (la más reciente)
local function accountWith(gdb, name, exceptId, skip)
    local best, bestId
    for id, acc in pairs(gdb.accounts) do
        if id ~= exceptId and not (skip and skip[id]) and type(acc.chars) == "table" and acc.chars[name]
            and (not best or (acc.updated or 0) > (best.updated or 0)) then
            best, bestId = acc, id
        end
    end
    return best, bestId
end

-- Elección simple: responde a los HELLO el usuario online con nombre menor
local function iAmRelay(exclude)
    local me = SG:MyName()
    for name, t in pairs(SG.addonOnline) do
        if name ~= exclude and GetTime() - t < 900 and name < me then return false end
    end
    return true
end

local relayPending = {}

Comm:Register("HELLO", function(msg, sender)
    SG.addonOnline[sender] = GetTime()
    local gdb = SG:GuildDB(); if gdb then gdb.seen[sender] = SG:Now() end
    -- respondo con mi perfil por susurro
    C_Timer.After(1 + math.random() * 4, function() SG:BroadcastProfile("WHISPER", sender) end)
    -- el relay manda lo que el recién llegado no tiene (cuentas de gente offline)
    if iAmRelay(sender) and gdb then
        local digest = msg.d or {}
        C_Timer.After(6 + math.random() * 4, function()
            for id, acc in pairs(gdb.accounts) do
                if (acc.updated or 0) > (digest[id] or 0) and id ~= msg.id then
                    Comm:Send({ t = "RELAY", id = id, main = acc.main, chars = acc.chars,
                        updated = acc.updated, milestones = acc.milestones,
                        earned = acc.earned }, "WHISPER", sender)
                end
            end
            SG:Fire("HELLO_RELAY", msg, sender)
        end)
    end
    -- datos vacíos: le mando su cuenta si la tengo
    if msg.fresh and gdb then
        local acc, id = accountWith(gdb, sender, msg.id)
        if acc then
            C_Timer.After(1 + math.random() * 3, function()
                Comm:Send({ t = "RELAY", id = id, main = acc.main, chars = acc.chars,
                    updated = acc.updated, milestones = acc.milestones,
                    earned = acc.earned }, "WHISPER", sender)
            end)
        end
    end
    SG:Fire("HELLO_RECEIVED", msg, sender)
end)

Comm:Register("PROF", function(msg, sender)
    SG.addonOnline[sender] = GetTime()
    local gdb = SG:GuildDB(); if gdb then gdb.seen[sender] = SG:Now() end
    if storeAccount(msg, sender) then SG:Fire("DATA_UPDATED") end
end)

local function wantsRestore()
    local pending = SG.db.my.restorePending
    if pending and SG:Now() - pending > RESTORE_DAYS * 86400 then
        SG.db.my.restorePending, pending = nil, nil
    end
    return SG.restoring or pending ~= nil
end

local function canRestoreFrom(id)
    local former = SG.db.my.formerIds
    return type(id) == "string" and id ~= SG.db.accountId and not (former and former[id])
end

-- Recuperación pendiente: ¿ya tengo guardada la cuenta antigua? (llega con los RELAY)
function SG:TryRestoreStored()
    if not wantsRestore() then return false end
    local gdb = self:GuildDB()
    if not gdb then return false end
    local acc, id = accountWith(gdb, self:MyName(), self.db.accountId, self.db.my.formerIds)
    if not acc then return false end
    restoreFrom({ id = id, main = acc.main, chars = acc.chars, milestones = acc.milestones, earned = acc.earned })
    return true
end

-- "/sg recuperar": vuelve a pedir a la guild la cuenta de este personaje
function SG:RequestRestore()
    self.db.my.restorePending = self:Now()
    if self:TryRestoreStored() then return end
    self:Print("Pidiendo tus datos a la guild... Si alguien conectado los tiene, te llegarán en unos segundos.")
    self:SendHello()
end

Comm:Register("RELAY", function(msg, sender)
    if wantsRestore() and canRestoreFrom(msg.id) and type(msg.chars) == "table"
        and type(msg.chars[SG:MyName()]) == "table" and SG:IsGuildMember(sender) then
        restoreFrom(msg)
        return
    end
    if storeAccount(msg, nil) then SG:Fire("DATA_UPDATED") end
end)

function SG:SendHello()
    local gdb = self:GuildDB()
    if not gdb then return end
    local digest = {}
    for id, acc in pairs(gdb.accounts) do digest[id] = acc.updated or 0 end
    Comm:Send({
        t = "HELLO", v = self.version, id = self.db.accountId, d = digest,
        sv = gdb.settings.ver or 0, ev = self.Events and self.Events:LatestModified() or 0,
        fresh = wantsRestore() or nil,
    }, "GUILD")
    self:BroadcastProfile("GUILD")
end

SG:Listen("REQUEST_SYNC", function() SG:SendHello() end)

---------------------------------------------------------------------------
-- Main / alters
---------------------------------------------------------------------------
function SG:SetMain(name)
    if not self.db.my.chars[name] then return end
    self.db.my.main = name
    self:Print("Tu main ahora es " .. name .. ". Tus estadísticas siguen sumando igual.")
    self:BroadcastProfile()
    self:Fire("DATA_UPDATED")
end

---------------------------------------------------------------------------
-- Ciclo de vida
---------------------------------------------------------------------------
function P:OnLogin()
    if SG.restoring then
        -- si nadie tiene la cuenta de este personaje, es un jugador nuevo de verdad
        C_Timer.After(RESTORE_WINDOW, function()
            if not SG.restoring then return end
            SG.restoring = false
            SG.db.my.restorePending = SG:Now()
            SG:Fire("RESTORE_DONE")
            SG:MarkDirty()
            SG:BroadcastProfile()
        end)
    end
    SG:RequestRoster()
    if SetGuildRosterShowOffline then SetGuildRosterShowOffline(true) end
    C_Timer.After(8, function()
        SG:RefreshMyChar()
        SG:TryRestoreStored()
        if IsInGuild() then SG:SendHello() end
    end)
    -- cada minuto el perfil, si ha cambiado; cada 5 siempre, para quien acaba de llegar
    local beats = 0
    C_Timer.NewTicker(60, function()
        SG:RequestRoster()
        beats = beats + 1
        if IsInGuild() and (dirty or beats % 5 == 0 or profileKey(SG:BuildMyProfile(true)) ~= sentKey) then
            SG:BroadcastProfile()
        end
    end)
end

SG:On("PLAYER_GUILD_UPDATE", function()
    local c = SG:MyChar()
    c.guild = SG:GuildName()
    SG:RequestRoster()
end)

SG:On("PLAYER_LOGOUT", function()
    SG:RefreshMyChar(true)
end)
