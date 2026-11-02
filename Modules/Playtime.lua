-- SolfaGuild - Tiempo de juego (solo ranking, sin mensajes)

local _, ns = ...
local SG = ns.SG

local PT = SG:RegisterModule("Playtime", {})
SG.Playtime = PT

local base, baseAt  -- segundos /played y GetTime() en el momento de recibirlo
local silent = false

function PT:Update()
    if base then SG:MyChar().played = base + math.floor(GetTime() - baseAt) end
end

function PT:OnLogin()
    C_Timer.After(12, function()
        -- pedimos /played sin ensuciar el chat
        silent = true
        local orig = ChatFrame_DisplayTimePlayed
        if orig then
            ChatFrame_DisplayTimePlayed = function() end
            C_Timer.After(5, function()
                if ChatFrame_DisplayTimePlayed ~= orig then ChatFrame_DisplayTimePlayed = orig end
                silent = false
            end)
        end
        PT.restore = orig
        RequestTimePlayed()
    end)
end

SG:On("TIME_PLAYED_MSG", function(total)
    base, baseAt = total, GetTime()
    SG:MyChar().played = total
    SG:MarkDirty()
    -- la función original se restaura con el temporizador (los marcos de chat
    -- procesan este mismo evento después que nosotros)
end)
