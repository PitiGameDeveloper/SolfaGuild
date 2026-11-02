-- SolfaGuild - Oro: total recolectado (vida de la cuenta) y oro actual.
-- No cuenta como "recolectado" el oro que te envías por correo desde tus alters.

local _, ns = ...
local SG = ns.SG

local Gold = SG:RegisterModule("Gold", {})
SG.Gold = Gold

local last
local ignore = { amount = 0, until_ = 0 }

local function fmt(v) return SG:FormatMoney(v) end

function Gold:OnLogin()
    last = GetMoney()
    local c = SG:MyChar()
    c.gold = last
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
    if not last then last = now; return end
    local delta = now - last
    last = now
    local c = SG:MyChar()
    c.gold = now
    if delta > 0 then
        if ignore.amount > 0 and GetTime() <= ignore.until_ then
            local skip = math.min(delta, ignore.amount)
            ignore.amount = ignore.amount - skip
            delta = delta - skip
        else
            ignore.amount = 0
        end
        c.earned = (c.earned or 0) + delta
    end
    SG:MarkDirty()
    if not SG:Feature("gold") then return end
    local t = SG.Milestones:MyTotals()
    SG.Milestones:Check("goldE", SG.Texts.goldEarned, t.earned, "HITO DE ORO", nil, fmt)
    SG.Milestones:Check("goldH", SG.Texts.goldHeld, now, "HITO DE ORO", nil, fmt)
end)
