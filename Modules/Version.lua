-- SolfaGuild - Aviso de versión nueva
-- Cada uno dice su versión al conectarse (HELLO) y en su perfil (PROF). Si alguien de la
-- guild tiene una más nueva que la mía, sale un aviso en el chat enseguida y luego cada
-- 10 minutos, hasta que actualice (al hacer /reload con la nueva ya no sale).

local _, ns = ...
local SG = ns.SG

local V = SG:RegisterModule("Version", {})
SG.Version = V

local EVERY = 600
V.newest = nil   -- versión más nueva vista en la guild (texto), si es mayor que la mía
local ticker

-- "0.4.24" -> { 0, 4, 24 }; nil si no es una versión
local function parse(v)
    if type(v) ~= "string" or not v:match("^%d+[%.%d]*$") then return nil end
    local out = {}
    for n in v:gmatch("%d+") do out[#out + 1] = tonumber(n) end
    return out
end

-- ¿a es más nueva que b?
function V.Newer(a, b)
    local pa, pb = parse(a), parse(b)
    if not pa or not pb then return false end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

local function warn()
    if not V.newest then return end
    SG:Print(SG:Fmt(SG.Texts.ui.newVersion, { new = V.newest, old = SG.version }))
end

local function seen(v)
    if not V.Newer(v, SG.version) then return end
    if V.newest and not V.Newer(v, V.newest) then return end
    V.newest = v
    if not ticker then
        warn()
        ticker = C_Timer.NewTicker(EVERY, function() SG:Try(warn) end)
    end
end

local function onMsg(msg)
    if type(msg) == "table" then seen(msg.v) end
end
SG.Comm:Register("HELLO", onMsg)
SG.Comm:Register("PROF", onMsg)
