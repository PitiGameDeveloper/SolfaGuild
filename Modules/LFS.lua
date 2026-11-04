-- SolfaGuild - Looking for Solfamidas (LFS)
-- Quien busca grupo (el "líder") elige mazmorra y funciones. Su cliente decide a
-- quién avisar con lo que ya sabe de la guild (perfiles y roster), le susurra la
-- oferta y cubre la plaza según le contestan. Nada se envía a toda la guild.
--
-- Orden de aviso (cada cuenta, una vez por búsqueda), con el mejor personaje de la
-- cuenta para lo que falta: en rango sin hacerla > en rango ya hecha > por encima
-- del rango, de menos nivel a más. Por debajo del mínimo no se avisa nunca.
--
-- Una oferta cada vez, para que dos personas no elijan la misma plaza. Si solo
-- faltan DPS no hay conflicto posible: sale una oferta por cada DPS que falte.
--
-- Mensajes (todos por susurro):
--   LFS_OFFER  líder -> jugador    te ofrezco esta plaza
--   LFS_ACK    jugador -> líder    la estoy viendo (sin él se pasa al siguiente enseguida)
--   LFS_ANS    jugador -> líder    acepto con esta función / no
--   LFS_OK     líder -> jugador    plaza tuya: sal de tu grupo
--   LFS_READY  jugador -> líder    ya estoy fuera y con el personaje: invítame
--   LFS_CANCEL líder -> jugador    la búsqueda ya no sigue

local _, ns = ...
local SG = ns.SG
local Comm = SG.Comm

local LFS = SG:RegisterModule("LFS", {})
SG.LFS = LFS

local MAX_GROUP   = 5      -- jugadores en una mazmorra
local ACK_TIME    = 5      -- s para que su cliente confirme que ha visto la oferta
local RETRY_EVERY = 8      -- s sin entrar para volver a invitar
local MAX_TRIES   = 4
local ANSWER_WAIT = 10     -- s para que el líder confirme la plaza
local GOING_MAX   = 900    -- s como mucho esperando a entrar en el grupo
local ROLE_ORDER  = { "T", "H", "D" }
LFS.ROLE_ORDER = ROLE_ORDER

local run        -- búsqueda propia en curso (ver LFS:Start)
local last       -- cómo acabó la última búsqueda: { d, need, answers, complete, text }
local offer      -- oferta que estoy viendo: { id, from, dungeon, char, roles }
local going      -- plaza aceptada: { id, from, t } (se acepta sola su invitación)
local ticker

local function changed() SG:Fire("LFS_CHANGED") end

---------------------------------------------------------------------------
-- Grupo (API nueva si existe, si no la antigua)
---------------------------------------------------------------------------
local function leaveGroup()
    if C_PartyInfo and C_PartyInfo.LeaveParty then C_PartyInfo.LeaveParty() else LeaveParty() end
end

local function invite(name)
    name = SG:Target(name)
    if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(name) else InviteUnit(name) end
end

local function inGroupWith(name) return SG:InMyGroup(name) end

local function groupSize()
    return IsInGroup() and GetNumGroupMembers() or 1
end

-- ¿Puedo buscar? Devuelve las plazas libres, o nil y el motivo.
function LFS:FreeSlots()
    if IsInRaid() then return nil, "Estás en una banda: el LFS es para grupos de mazmorra." end
    if IsInGroup() and not UnitIsGroupLeader("player") then
        return nil, "Solo puede buscar el líder del grupo. Sal del grupo o pídele el liderazgo."
    end
    return MAX_GROUP - groupSize()
end

function LFS:Run() return run end

---------------------------------------------------------------------------
-- Candidatos
---------------------------------------------------------------------------
local function rolesFor(class, need)
    local can = SG.ClassRoles[class or ""] or { D = true }
    local out
    for _, role in ipairs(ROLE_ORDER) do
        if can[role] and (need[role] or 0) > 0 then out = (out or "") .. role end
    end
    return out
end

-- Personaje de quien está conectado (nil = la cuenta no está conectada)
local function onlineChar(acc)
    for name in pairs(acc.chars) do
        local r = SG.roster[name]
        if r and r.online then return name end
    end
end

-- 1 = en rango sin hacer, 2 = en rango ya hecha, 3 = por encima; nil = no puede ir
local function tierOf(d, level, char)
    if level < d.min then return nil end
    if level > d.max then return 3 end
    return ((char.dungeons and char.dungeons[d.id] or 0) > 0) and 2 or 1
end

local function better(a, b)
    if a.tier ~= b.tier then return a.tier < b.tier end
    if a.tier == 3 and a.level ~= b.level then return a.level < b.level end
    if a.logged ~= b.logged then return a.logged end
    if a.level ~= b.level then return a.level < b.level end
    return a.char < b.char
end

-- Mejor personaje de una cuenta para esa mazmorra y lo que falta, o nil
local function bestChar(acc, d, need, online)
    local best
    for name, c in pairs(acc.chars) do
        local r = SG.roster[name]
        -- el roster está más al día que el perfil, que viaja cada minuto como mucho
        local level = math.max(r and r.level or 0, c.level or 0)
        local class = c.class or (r and r.class)
        local tier = tierOf(d, level, c)
        local roles = tier and rolesFor(class, need)
        if roles then
            local it = { acc = acc, char = name, online = online, level = level, class = class, tier = tier,
                roles = roles, logged = name == online }
            if not best or better(it, best) then best = it end
        end
    end
    return best
end

-- Candidatos ordenados. tried: cuentas ya avisadas en esta búsqueda.
function LFS:Candidates(d, need, tried)
    local out = {}
    for id, acc in pairs(SG:Accounts()) do
        if not acc.mine and not (tried and tried[id]) then
            local online = onlineChar(acc)
            if online and not inGroupWith(online) then
                local best = bestChar(acc, d, need, online)
                if best then out[#out + 1] = best end
            end
        end
    end
    table.sort(out, better)
    return out
end

---------------------------------------------------------------------------
-- Líder: la búsqueda
---------------------------------------------------------------------------
local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function needTotal(need) return need.T + need.H + need.D end

-- "1 tanque, 2 DPS"
function LFS:NeedText(need)
    local parts = {}
    if need.T > 0 then parts[#parts + 1] = need.T .. " tanque" end
    if need.H > 0 then parts[#parts + 1] = need.H .. " sanador" end
    if need.D > 0 then parts[#parts + 1] = need.D .. " DPS" end
    return table.concat(parts, ", ")
end

function LFS:LastResult() return last end
function LFS:ClearResult() last = nil end

-- Apunta cómo va cada persona a la que se ha avisado (ver Texts.ui.lfsState)
local function note(name, state, char, class, role)
    local a = run.answers[name] or {}
    run.answers[name] = a
    a.state = state
    a.char, a.class, a.role = char or a.char, class or a.class, role or a.role
    return a
end

-- Quien no va, también por el chat, por si la ventana está cerrada
local function noteOut(name, state)
    local a = note(name, state)
    SG:Print((a.char or name) .. ": " .. SG.Texts.ui.lfsState[state])
end

-- Ofertas que pueden estar abiertas a la vez
local function allowedOffers(need)
    if need.T == 0 and need.H == 0 then return need.D end
    return 1
end

-- done: ha acabado sola, no porque se haya cancelado, y se enseña el resultado
local function finish(text, done)
    if not run then return end
    for name in pairs(run.offers) do
        Comm:Send({ t = "LFS_CANCEL", id = run.id }, "WHISPER", name)
    end
    for name in pairs(run.slots) do
        Comm:Send({ t = "LFS_CANCEL", id = run.id }, "WHISPER", name)
    end
    last = done and { d = run.d, need = run.need, answers = run.answers, text = done,
        complete = needTotal(run.need) == 0 } or nil
    run = nil
    if ticker then ticker:Cancel(); ticker = nil end
    if text then SG:Print(text) end
    changed()
    if last then SG:Fire("LFS_FINISHED") end
end

local function pump()
    if not run then return end
    local free = LFS:FreeSlots()
    if not free then
        finish("Búsqueda cancelada: ya no eres líder del grupo.", "Búsqueda cancelada: ya no eres líder del grupo")
        return
    end
    -- quien ya ha entrado cuenta en el grupo, no como plaza reservada
    for name in pairs(run.slots) do
        if inGroupWith(name) then
            run.slots[name] = nil
            note(name, "inside")
        end
    end
    -- alguien ha entrado por su cuenta: las plazas que ya no caben se dejan de buscar
    local room = free - count(run.slots)
    local total = needTotal(run.need)
    while total > room and total > 0 do
        for _, role in ipairs({ "D", "H", "T" }) do
            if run.need[role] > 0 then run.need[role] = run.need[role] - 1; break end
        end
        total = total - 1
    end
    local allowed = allowedOffers(run.need)
    if count(run.offers) < allowed then
        local cands = LFS:Candidates(run.d, run.need, run.tried)
        local i = 1
        while count(run.offers) < allowed and cands[i] do
            local c = cands[i]
            run.tried[c.acc.id] = true
            run.offers[c.online] = { t = GetTime(), char = c.char, class = c.class }
            note(c.online, "wait", c.char, c.class)
            Comm:Send({ t = "LFS_OFFER", id = run.id, dg = run.d.id, char = c.char, level = c.level,
                roles = c.roles, secs = run.secs }, "WHISPER", c.online)
            i = i + 1
        end
    end
    -- sin plazas por cubrir y todos dentro: listo. Sin ofertas ni candidatos: no hay más gente.
    if not next(run.offers) and not next(run.slots) then
        if needTotal(run.need) == 0 then
            finish("¡Grupo completo para |cffffd100" .. run.d.name .. "|r!", "¡Grupo completo!")
        else
            finish("No queda ningún Solfamida al que avisar para |cffffd100" .. run.d.name .. "|r. Faltan: "
                .. LFS:NeedText(run.need) .. ".", "No queda nadie a quien avisar")
        end
        return
    end
    -- falta gente y no hay a quién avisar, pero aún hay alguien de camino
    local exhausted = needTotal(run.need) > 0 and not next(run.offers)
    if exhausted and not run.exhausted then
        SG:Print("No queda nadie más a quien avisar. Faltan: " .. LFS:NeedText(run.need) .. ".")
    end
    run.exhausted = exhausted
    changed()
end

-- Devuelve una plaza a la búsqueda
local function reopen(name)
    local s = run.slots[name]
    if not s then return end
    run.slots[name] = nil
    run.need[s.role] = run.need[s.role] + 1
end

local function tick()
    SG:Try(function()
        if not run then return end
        local now = GetTime()
        for name, o in pairs(run.offers) do
            if (not o.seen and now - o.t > ACK_TIME) or now - o.t > run.secs + ACK_TIME then
                run.offers[name] = nil
                noteOut(name, o.seen and "late" or "lost")
            end
        end
        for name, s in pairs(run.slots) do
            if inGroupWith(name) then
                run.slots[name] = nil
                note(name, "inside")
            elseif s.ready then
                if now - s.t >= RETRY_EVERY then
                    if s.tries >= MAX_TRIES then
                        SG:Print(name .. " no ha podido entrar en el grupo. Se busca a otro.")
                        Comm:Send({ t = "LFS_CANCEL", id = run.id }, "WHISPER", name)
                        note(name, "failed")
                        reopen(name)
                    else
                        s.t, s.tries = now, s.tries + 1
                        invite(name)
                    end
                end
            elseif now > s.expires then
                SG:Print(s.char .. " no se ha conectado a tiempo. Se busca a otro.")
                Comm:Send({ t = "LFS_CANCEL", id = run.id }, "WHISPER", name)
                note(name, "failed")
                reopen(name)
            end
        end
        pump()
    end)
end

-- need = { T = 0/1, H = 0/1, D = 0..4 }. Devuelve true, o nil y el motivo.
function LFS:Start(d, need)
    if run then return nil, "Ya tienes una búsqueda en curso." end
    if not SG:Feature("lfs") then return nil, "El GM ha desactivado el LFS." end
    local free, why = self:FreeSlots()
    if not free then return nil, why end
    local total = needTotal(need)
    if total < 1 then return nil, "Elige qué quieres buscar." end
    if total > free then return nil, "Solo te quedan " .. free .. " plazas libres en el grupo." end
    if #self:Candidates(d, need) == 0 then return nil, "Ahora mismo no hay ningún Solfamida disponible para esto." end
    local cfg = SG:Cfg()
    last = nil
    run = { id = SG:MyName() .. ":" .. SG:RandomId(6), d = d, need = need, offers = {}, slots = {}, tried = {}, answers = {},
        secs = cfg.lfsOfferTime or 30, relog = (cfg.lfsRelogTime or 5) * 60 }
    ticker = C_Timer.NewTicker(1, tick)
    pump()
    return true
end

function LFS:Cancel()
    finish("Búsqueda cancelada.")
end

Comm:Register("LFS_ACK", function(msg, sender)
    local o = run and msg.id == run.id and run.offers[sender]
    if o then o.seen = true end
end)

Comm:Register("LFS_ANS", function(msg, sender)
    if not run or msg.id ~= run.id then return end
    local o = run.offers[sender]
    if not o then return end
    run.offers[sender] = nil
    if msg.ok then
        local role = msg.role
        if (run.need[role] or 0) < 1 then
            note(sender, "taken")
            Comm:Send({ t = "LFS_CANCEL", id = run.id, taken = true }, "WHISPER", sender)
        else
            run.need[role] = run.need[role] - 1
            run.slots[sender] = { role = role, char = o.char, class = o.class, t = 0, tries = 0,
                expires = GetTime() + run.relog }
            note(sender, "yes", nil, nil, role)
            Comm:Send({ t = "LFS_OK", id = run.id, relog = run.relog }, "WHISPER", sender)
        end
    else
        noteOut(sender, (msg.why == "busy" or msg.why == "late") and msg.why or "no")
    end
    pump()
end)

-- Llega desde el personaje que va: si ha cambiado de personaje el remitente es otro
Comm:Register("LFS_READY", function(msg, sender)
    if not run or msg.id ~= run.id then return end
    local key = sender
    if not run.slots[key] then
        key = nil
        for name, s in pairs(run.slots) do
            if s.char == sender then key = name end
        end
        if not key then return end
        run.slots[sender], run.slots[key] = run.slots[key], nil
        run.answers[sender], run.answers[key] = run.answers[key], nil
    end
    local s = run.slots[sender]
    s.ready, s.tries, s.t = true, 1, GetTime()
    SG:Print(sender .. " se apunta como " .. (SG.Texts.ui["lfsRole" .. s.role] or s.role) .. ". Invitándole al grupo...")
    invite(sender)
    changed()
end)

---------------------------------------------------------------------------
-- Jugador: recibir la oferta
---------------------------------------------------------------------------
-- why: "busy" (ocupado, ni la ha visto) o "late" (se le acabó el tiempo)
local function answerNo(id, leader, why)
    Comm:Send({ t = "LFS_ANS", id = id, ok = false, why = why }, "WHISPER", leader)
end

-- ¿Estoy para que me molesten? En mazmorra o en combate se pasa al siguiente.
local function busy()
    -- si el líder se ha desconectado nadie va a avisar de que esto ha acabado
    if going and GetTime() - going.t > GOING_MAX then going = nil end
    local inInstance = IsInInstance()
    return inInstance or SG:InCombat() or offer ~= nil or going ~= nil or SG.restoring
end

Comm:Register("LFS_OFFER", function(msg, sender)
    if type(msg.id) ~= "string" or type(msg.roles) ~= "string" then return end
    if not SG:Feature("lfs") or not SG:IsGuildMember(sender) then return end
    local d = SG.DungeonById[msg.dg]
    -- un personaje que no es mío, o de una versión con otra lista de mazmorras
    local isBusy = busy()
    if not d or not SG.db.my.chars[msg.char] or isBusy then
        answerNo(msg.id, sender, isBusy and "busy" or nil)
        return
    end
    Comm:Send({ t = "LFS_ACK", id = msg.id }, "WHISPER", sender)
    offer = { id = msg.id, from = sender, dungeon = d, char = msg.char, level = msg.level,
        class = SG.db.my.chars[msg.char].class, roles = msg.roles, secs = msg.secs or 30 }
    SG:Fire("LFS_OFFER_SHOW", offer)
end)

-- La ventana contesta aquí. role = nil: rechaza (why = "late": se le ha acabado el tiempo).
function LFS:Answer(role, why)
    if not offer then return end
    local o = offer
    offer = nil
    if not role then
        answerNo(o.id, o.from, why)
        return
    end
    going = { id = o.id, from = o.from, t = GetTime(), char = o.char, dungeon = o.dungeon, wait = true }
    Comm:Send({ t = "LFS_ANS", id = o.id, ok = true, role = role }, "WHISPER", o.from)
    C_Timer.After(ANSWER_WAIT, function()
        if going and going.id == o.id and going.wait then going = nil end
    end)
end

local waitingLeave

local function sendReady()
    waitingLeave = nil
    if going then Comm:Send({ t = "LFS_READY", id = going.id }, "WHISPER", going.from) end
end

-- Con el personaje bueno: se sale del grupo y, ya fuera, se pide la invitación
local function prepare()
    if not going then return end
    if inGroupWith(going.from) then return end
    if not IsInGroup() then sendReady(); return end
    waitingLeave = true
    leaveGroup()
    C_Timer.After(5, function() if waitingLeave then sendReady() end end)
end

Comm:Register("LFS_OK", function(msg, sender)
    if not going or msg.id ~= going.id or sender ~= going.from then return end
    going.wait = nil
    going.relog = msg.relog or 300
    if going.char == SG:MyName() then
        SG:Print(SG:Fmt(SG.Texts.ui.lfsGoing, { who = sender, dungeon = going.dungeon.name }))
        prepare()
    else
        -- sobrevive al cambio de personaje; al entrar con él se sigue (ver OnLogin)
        SG.db.my.lfsPending = { id = going.id, from = sender, char = going.char, dg = going.dungeon.id,
            expires = SG:Now() + going.relog }
        SG:Print(SG:Fmt(SG.Texts.ui.lfsRelog, { char = going.char, min = math.ceil(going.relog / 60), who = sender }))
        local id = going.id
        C_Timer.After(going.relog, function()
            if going and going.id == id then going = nil end
        end)
    end
end)

Comm:Register("LFS_CANCEL", function(msg, sender)
    if offer and offer.id == msg.id then
        offer = nil
        SG:Fire("LFS_OFFER_HIDE")
    end
    if going and going.id == msg.id then
        if msg.taken then SG:Print(SG.Texts.ui.lfsTaken)
        elseif not going.wait then SG:Print(SG.Texts.ui.lfsCancelled) end
        going = nil
    end
    local p = SG.db.my.lfsPending
    if p and p.id == msg.id then SG.db.my.lfsPending = nil end
end)

SG:On("GROUP_ROSTER_UPDATE", function()
    if waitingLeave and not IsInGroup() then sendReady() end
    if going and inGroupWith(going.from) then going = nil end
    if run then SG:Try(pump) end
end)

-- Aceptar sola la invitación del líder
SG:On("PARTY_INVITE_REQUEST", function(inviter)
    if not going or going.wait or SG:Short(inviter) ~= going.from then return end
    AcceptGroup()
    C_Timer.After(0.1, function() if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end end)
end)

-- Ha aceptado con otro personaje: al entrar con él se avisa al líder
function LFS:OnLogin()
    local p = SG.db.my.lfsPending
    if not p then return end
    if p.char ~= SG:MyName() then
        if SG:Now() > p.expires then SG.db.my.lfsPending = nil end
        return
    end
    SG.db.my.lfsPending = nil
    if SG:Now() > p.expires or not SG.DungeonById[p.dg] then return end
    going = { id = p.id, from = p.from, t = GetTime(), char = p.char, dungeon = SG.DungeonById[p.dg] }
    C_Timer.After(5, function()
        if not going then return end
        SG:Print(SG:Fmt(SG.Texts.ui.lfsGoing, { who = going.from, dungeon = going.dungeon.name }))
        prepare()
    end)
end
