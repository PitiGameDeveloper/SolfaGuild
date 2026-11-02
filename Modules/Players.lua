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
            name = SG:Short(name)
            roster[name] = {
                rank = rank, rankIndex = rankIndex, level = level,
                class = classFile, zone = zone, online = online and true or false,
            }
            if rankIndex == 0 then SG.gmName = name end
        end
    end
    SG.roster = roster
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

function SG:RefreshMyChar()
    local c = self:MyChar()
    c.level = UnitLevel("player")
    c.class = select(2, UnitClass("player"))
    c.guild = self:GuildName()
    c.gold = GetMoney()
    local wk = self:WeekKey()
    if c.weekKey ~= wk then c.weekKey = wk; c.killsWeek = 0 end
    if self.Playtime then self.Playtime:Update() end
    return c
end

-- Personajes de mi cuenta que están en la guild actual
function SG:MyGuildChars()
    local g = self:GuildName()
    local out = {}
    for name, c in pairs(self.db.my.chars) do
        if c.guild == g or name == self:MyName() then out[name] = c end
    end
    return out
end

function SG:BuildMyProfile()
    self:RefreshMyChar()
    local chars = {}
    for name, c in pairs(self:MyGuildChars()) do
        chars[name] = {
            class = c.class, level = c.level,
            kills = c.kills, killsWeek = c.killsWeek, weekKey = c.weekKey,
            gold = c.gold, earned = c.earned, played = c.played,
            dungeons = c.dungeons, zones = topN(c.zones, 8), partners = topN(c.partners, 8),
        }
    end
    for name in pairs(self.db.my.manualAlts) do
        if not chars[name] then chars[name] = { manual = true } end
    end
    local main = self.db.my.main
    if not chars[main] then main = self:MyName() end
    return {
        id = self.db.accountId,
        main = main,
        chars = chars,
        updated = self:Now(),
        milestones = self.db.my.milestones,
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
    if not gdb then return list end
    local mine = self:MyAccount()
    list[mine.id] = mine
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
            local copy = { id = id, main = acc.main, updated = acc.updated, chars = {}, milestones = acc.milestones }
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

-- Suma un campo de todos los personajes de una cuenta
function SG:AccountSum(acc, field)
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
        if v and v > 0 then out[#out + 1] = { acc = acc, value = v } end
    end
    table.sort(out, function(a, b) return a.value > b.value end)
    return out
end

---------------------------------------------------------------------------
-- Sincronización
---------------------------------------------------------------------------
local dirty = false
function SG:MarkDirty() dirty = true end

function SG:BroadcastProfile(channel, target)
    if not IsInGuild() then return end
    local p = self:BuildMyProfile()
    p.t = "PROF"
    Comm:Send(p, channel or "GUILD", target)
    if not channel or channel == "GUILD" then dirty = false end
end

local function storeAccount(p, sender)
    local gdb = SG:GuildDB()
    if not gdb or type(p.id) ~= "string" or type(p.chars) ~= "table" then return false end
    if p.id == SG.db.accountId then return false end
    local old = gdb.accounts[p.id]
    if old and (old.updated or 0) >= (p.updated or 0) then return false end
    gdb.accounts[p.id] = { main = p.main, chars = p.chars, updated = p.updated, milestones = p.milestones }
    for name in pairs(p.chars) do gdb.seen[name] = gdb.seen[name] or p.updated end
    -- el GM solo se reconoce si el perfil lo envía el propio GM
    if sender and SG.gmName and sender == SG.gmName and p.chars[sender] then
        gdb.gmAccount = p.id
    end
    return true
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
                        updated = acc.updated, milestones = acc.milestones }, "WHISPER", sender)
                end
            end
            SG:Fire("HELLO_RELAY", msg, sender)
        end)
    end
    SG:Fire("HELLO_RECEIVED", msg, sender)
end)

Comm:Register("PROF", function(msg, sender)
    SG.addonOnline[sender] = GetTime()
    local gdb = SG:GuildDB(); if gdb then gdb.seen[sender] = SG:Now() end
    if storeAccount(msg, sender) then SG:Fire("DATA_UPDATED") end
end)

Comm:Register("RELAY", function(msg, sender)
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
    }, "GUILD")
    self:BroadcastProfile("GUILD")
end

SG:Listen("REQUEST_SYNC", function() SG:SendHello() end)

---------------------------------------------------------------------------
-- Main / alters
---------------------------------------------------------------------------
function SG:SetMain(name)
    if not self.db.my.chars[name] and not self.db.my.manualAlts[name] then return end
    self.db.my.main = name
    self:Print("Tu main ahora es " .. name .. ". Tus estadísticas siguen sumando igual.")
    self:BroadcastProfile()
    self:Fire("DATA_UPDATED")
end

function SG:AddManualAlt(name)
    name = strtrim(name or "")
    if name == "" then return end
    name = name:sub(1, 1):upper() .. name:sub(2)
    self.db.my.manualAlts[name] = true
    self:BroadcastProfile()
    self:Fire("DATA_UPDATED")
end

function SG:RemoveAlt(name)
    if name == self:MyName() then return end
    self.db.my.manualAlts[name] = nil
    local c = self.db.my.chars[name]
    if c then c.guild = nil end  -- deja de contar para esta guild
    if self.db.my.main == name then self.db.my.main = self:MyName() end
    self:BroadcastProfile()
    self:Fire("DATA_UPDATED")
end

---------------------------------------------------------------------------
-- Ciclo de vida
---------------------------------------------------------------------------
function P:OnLogin()
    SG:RequestRoster()
    if SetGuildRosterShowOffline then SetGuildRosterShowOffline(true) end
    C_Timer.After(8, function()
        SG:RefreshMyChar()
        if IsInGuild() then SG:SendHello() end
    end)
    C_Timer.NewTicker(60, function()
        SG:RequestRoster()
        if dirty and IsInGuild() then SG:BroadcastProfile() end
    end)
    -- latido cada 5 min para quien acaba de llegar
    C_Timer.NewTicker(300, function()
        if IsInGuild() then SG:BroadcastProfile() end
    end)
end

SG:On("PLAYER_GUILD_UPDATE", function()
    local c = SG:MyChar()
    c.guild = SG:GuildName()
    SG:RequestRoster()
end)

SG:On("PLAYER_LOGOUT", function()
    SG:RefreshMyChar()
end)
