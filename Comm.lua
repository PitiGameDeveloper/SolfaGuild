-- SolfaGuild - Comunicación entre clientes (canal de addon de GUILD / WHISPER)
-- Serializador propio (sin librerías), troceado de mensajes y cola con límite.

local _, ns = ...
local SG = ns.SG

local Comm = {}
SG.Comm = Comm

---------------------------------------------------------------------------
-- Serializador: n<num>;  s<len>:<bytes>  T F N  { k v k v ... }
---------------------------------------------------------------------------
local function ser(v, out)
    local t = type(v)
    if t == "number" then
        out[#out + 1] = "n" .. string.format("%.14g", v) .. ";"
    elseif t == "string" then
        out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "boolean" then
        out[#out + 1] = v and "T" or "F"
    elseif t == "table" then
        out[#out + 1] = "{"
        for k, val in pairs(v) do
            local kt = type(k)
            if (kt == "string" or kt == "number") and type(val) ~= "function" then
                ser(k, out)
                ser(val, out)
            end
        end
        out[#out + 1] = "}"
    else
        out[#out + 1] = "N"
    end
end

function Comm:Serialize(v)
    local out = {}
    ser(v, out)
    return table.concat(out)
end

local function deser(s, pos)
    local c = s:sub(pos, pos)
    if c == "n" then
        local e = s:find(";", pos, true)
        return tonumber(s:sub(pos + 1, e - 1)), e + 1
    elseif c == "s" then
        local e = s:find(":", pos, true)
        local len = tonumber(s:sub(pos + 1, e - 1))
        return s:sub(e + 1, e + len), e + len + 1
    elseif c == "T" then return true, pos + 1
    elseif c == "F" then return false, pos + 1
    elseif c == "N" then return nil, pos + 1
    elseif c == "{" then
        local t = {}
        pos = pos + 1
        while s:sub(pos, pos) ~= "}" do
            if pos > #s then error("tabla sin cerrar") end
            local k, v
            k, pos = deser(s, pos)
            v, pos = deser(s, pos)
            if k ~= nil then t[k] = v end
        end
        return t, pos + 1
    end
    error("byte inesperado '" .. tostring(c) .. "' en " .. pos)
end

function Comm:Deserialize(s)
    local ok, v = pcall(deser, s, 1)
    if ok then return v end
    return nil
end

---------------------------------------------------------------------------
-- Envío con troceado y cola (límite de 255 bytes por mensaje)
---------------------------------------------------------------------------
local CHUNK = 230
local queue = {}
local msgCounter = 0
local sendFrame = CreateFrame("Frame")
local acc = 0
local INTERVAL = 0.12

local function rawSend(text, channel, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(SG.PREFIX, text, channel, target)
    else
        SendAddonMessage(SG.PREFIX, text, channel, target)
    end
end

sendFrame:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed
    if acc < INTERVAL then return end
    acc = 0
    local item = table.remove(queue, 1)
    if item then
        rawSend(item[1], item[2], item[3])
    else
        self:Hide()
    end
end)
sendFrame:Hide()

-- Envía una tabla { t = "TIPO", ... }
function Comm:Send(msg, channel, target)
    channel = channel or "GUILD"
    if channel == "GUILD" and not IsInGuild() then return end
    local data = self:Serialize(msg)
    msgCounter = (msgCounter + 1) % 1000
    local id = tostring(msgCounter)
    local total = math.ceil(#data / CHUNK)
    if total < 1 then total = 1 end
    for i = 1, total do
        local piece = data:sub((i - 1) * CHUNK + 1, i * CHUNK)
        table.insert(queue, { id .. "\t" .. i .. "\t" .. total .. "\t" .. piece, channel, target })
    end
    sendFrame:Show()
end

function Comm:QueueSize() return #queue end

---------------------------------------------------------------------------
-- Recepción
---------------------------------------------------------------------------
local buffers = {}
local receivers = {}

function Comm:Register(msgType, fn)
    receivers[msgType] = receivers[msgType] or {}
    table.insert(receivers[msgType], fn)
end

local function dispatch(msg, sender, channel)
    if type(msg) ~= "table" or type(msg.t) ~= "string" then return end
    local list = receivers[msg.t]
    if not list then return end
    for _, fn in ipairs(list) do
        SG:Try(fn, msg, sender, channel)
    end
end

SG:On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
    if prefix ~= SG.PREFIX then return end
    sender = SG:Short(sender)
    if not sender or sender == SG:MyName() then return end
    local id, idx, total, piece = text:match("^(%d+)\t(%d+)\t(%d+)\t(.*)$")
    if not id then return end
    idx, total = tonumber(idx), tonumber(total)
    local key = sender .. ":" .. id
    if total == 1 then
        dispatch(Comm:Deserialize(piece), sender, channel)
        return
    end
    local b = buffers[key]
    if not b or idx == 1 then
        b = { parts = {}, n = 0, time = GetTime() }
        buffers[key] = b
    end
    if not b.parts[idx] then
        b.parts[idx] = piece
        b.n = b.n + 1
    end
    if b.n == total then
        buffers[key] = nil
        dispatch(Comm:Deserialize(table.concat(b.parts)), sender, channel)
    end
end)

-- Limpieza de buffers incompletos
C_Timer.NewTicker(60, function()
    local now = GetTime()
    for k, b in pairs(buffers) do
        if now - b.time > 120 then buffers[k] = nil end
    end
end)

SG:RegisterModule("Comm", {
    OnInit = function()
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(SG.PREFIX)
        elseif RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix(SG.PREFIX)
        end
    end,
})
