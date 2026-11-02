-- SolfaGuild - Oro: solo cuenta el oro acumulado (vida de la cuenta).
-- La primera vez que entras con un personaje se suma el oro que ya tenía; a
-- partir de ahí suma todo lo que gana. No cuenta el oro que te envías por
-- correo desde tus alters (ya se contó al ganarlo).

local _, ns = ...
local SG = ns.SG

local Gold = SG:RegisterModule("Gold", {})
SG.Gold = Gold

local last
local ignore = { amount = 0, until_ = 0 }

local function fmt(v) return SG:FormatMoney(v) end

local function checkMilestones()
    if not SG:Feature("gold") then return end
    local t = SG.Milestones:MyTotals()
    SG.Milestones:Check("goldE", SG.Texts.goldEarned, t.earned, "HITO DE ORO", nil, fmt)
end

-- Primera vez con este personaje: su oro actual entra en el acumulado
local function seed(c, money)
    c.earned = (c.earned or 0) + money
    c.goldSeeded = true
    SG:MarkDirty()
    checkMilestones()
end

function Gold:OnLogin()
    last = GetMoney()
    local c = SG:MyChar()
    -- si el WoW aún devuelve 0, esperamos al primer cambio de dinero
    if not c.goldSeeded and last > 0 then seed(c, last) end
    -- correo de un alter propio => no es oro "ganado"
    if TakeInboxMoney then
        hooksecurefunc("TakeInboxMoney", function(index)
            local _, _, sender, _, money = GetInboxHeaderInfo(index)
            sender = SG:Short(sender)
            if sender and money and money > 0 and SG.db.my.chars[sender] then
                ignore.amount = ignore.amount + money
                ignore.until_ = GetTime() + 5
            end
        end)
    end
end

SG:On("PLAYER_MONEY", function()
    local now = GetMoney()
    local c = SG:MyChar()
    if not c.goldSeeded then
        last = now
        seed(c, now)
        return
    end
    if not last then last = now; return end
    local delta = now - last
    last = now
    if delta <= 0 then return end
    if ignore.amount > 0 and GetTime() <= ignore.until_ then
        local skip = math.min(delta, ignore.amount)
        ignore.amount = ignore.amount - skip
        delta = delta - skip
    else
        ignore.amount = 0
    end
    if delta <= 0 then return end
    c.earned = (c.earned or 0) + delta
    SG:MarkDirty()
    checkMilestones()
end)
