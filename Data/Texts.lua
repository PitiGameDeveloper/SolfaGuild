-- SolfaGuild - Textos y rangos (EDITAR AQUÍ los mensajes épicos)
-- %enemy%  -> "Alianza" / "Horda" según tu facción
-- %name%   -> nombre de tu main
-- %count%  -> número alcanzado
-- %zone%   -> zona

local _, ns = ...
local SG = ns.SG

SG.Texts = {}
local T = SG.Texts

---------------------------------------------------------------------------
-- RANGOS PVP (asesinatos de jugadores enemigos en mundo abierto)
---------------------------------------------------------------------------
T.pvpRanks = {
    { at = 1,    name = "Primera Sangre",            icon = "Interface\\Icons\\Ability_Rogue_Eviscerate",
      title = "¡Has derramado sangre %enemy%!",
      text  = "Por primera vez, la sangre de la %enemy% mancha tus manos. No será la última.\n\nHoy comienza tu camino, %name%. Los tambores de los Solfamidas ya suenan con tu nombre... y algún día sonarán como una leyenda." },
    { at = 5,    name = "Recluta de la Horda",       icon = "Interface\\Icons\\INV_Sword_04",
      title = "Recluta de la Horda",
      text  = "%count% enemigos han caído ante ti. Ya no eres un simple peón: eres un Recluta." },
    { at = 10,   name = "Grunt Solfamida",           icon = "Interface\\Icons\\INV_Axe_02",
      title = "Grunt Solfamida",
      text  = "%count% muertes. Tu hacha empieza a tener fama en las tabernas enemigas." },
    { at = 25,   name = "Sargento",                  icon = "Interface\\Icons\\INV_Shield_05",
      title = "Sargento",
      text  = "%count% enemigos. Los guardias de la %enemy% ya tienen un cartel con tu cara." },
    { at = 50,   name = "Cazador de la %enemy%",     icon = "Interface\\Icons\\Ability_Hunter_SniperShot",
      title = "Cazador",
      text  = "%count% presas. Cazas a la %enemy% como quien caza jabalíes en Durotar." },
    { at = 100,  name = "Centurión",                 icon = "Interface\\Icons\\INV_Helmet_03",
      title = "Centurión",
      text  = "¡CIEN! %count% enemigos. Thrall en persona ha oído hablar de ti." },
    { at = 250,  name = "Señor de la Guerra",        icon = "Interface\\Icons\\INV_Sword_48",
      title = "Señor de la Guerra",
      text  = "%count% almas enviadas al cementerio. Las madres de la %enemy% asustan a sus hijos con tu nombre." },
    { at = 500,  name = "Azote de la %enemy%",       icon = "Interface\\Icons\\Spell_Shadow_DeathScream",
      title = "Azote",
      text  = "%count%. Ya no es una guerra, es una costumbre." },
    { at = 1000, name = "Leyenda Solfamida",         icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
      title = "LEYENDA",
      text  = "%count% enemigos. Lo prometimos el primer día: te has convertido en leyenda. Los Solfamidas cantarán tu nombre para siempre." },
}

---------------------------------------------------------------------------
-- ESCALAFÓN PVP de la pestaña PvP: los jugadores se ordenan por asesinatos y
-- van llenando los rangos de arriba abajo. "players" = cuántos caben en ese
-- rango; el último (sin "players") se queda con todos los que sobren.
---------------------------------------------------------------------------
T.pvpLadder = {
    { name = "Señor de la Guerra", players = 1 },
    { name = "Campeones",          players = 3 },
    { name = "Veteranos",          players = 5 },
    { name = "Grunts",             players = 10 },
    { name = "Reclutas" },
}

---------------------------------------------------------------------------
-- ESCALAFÓN PVE de la pestaña PvE: igual que el de PvP, por mazmorras completadas.
---------------------------------------------------------------------------
T.pveLadder = {
    { name = "Leyenda de las Profundidades", players = 1 },
    { name = "Señores de las Criptas",       players = 3 },
    { name = "Rompemazmorras",               players = 5 },
    { name = "Veteranos",                    players = 10 },
    { name = "Exploradores" },
}

---------------------------------------------------------------------------
-- ORO: total recolectado en la vida de la cuenta
---------------------------------------------------------------------------
T.goldEarned = {
    { at = 10 * 10000,    name = "Ahorrador",        icon = "Interface\\Icons\\INV_Misc_Coin_01",
      title = "¡Tus primeros 10 de oro!", text = "Has recolectado %count% en total. Un pequeño paso para un orco, un gran paso para tu bolsa." },
    { at = 100 * 10000,   name = "Mercader",         icon = "Interface\\Icons\\INV_Misc_Coin_02",
      title = "100 de oro recolectados", text = "%count% han pasado por tus manos. Los goblins de Trinquete empiezan a respetarte." },
    { at = 1000 * 10000,  name = "Magnate",          icon = "Interface\\Icons\\INV_Misc_Coin_03",
      title = "¡1.000 de oro recolectados!", text = "%count%. Ya puedes mirar por encima del hombro al banquero de Orgrimmar." },
    { at = 5000 * 10000,  name = "Barón del Oro",    icon = "Interface\\Icons\\INV_Misc_Coin_04",
      title = "5.000 de oro recolectados", text = "%count%. Gallywix tiene envidia." },
}

---------------------------------------------------------------------------
-- MAZMORRAS completadas (jefe final)
---------------------------------------------------------------------------
T.dungeonRanks = {
    { at = 1,   name = "Explorador",        icon = "Interface\\Icons\\INV_Misc_Map_01",
      title = "¡Tu primera mazmorra!", text = "Has completado %dungeon%. La primera de muchas, %name%." },
    { at = 5,   name = "Saqueador",         icon = "Interface\\Icons\\INV_Misc_Bag_08",
      title = "5 mazmorras", text = "%count% mazmorras completadas. Ya sabes quién tira de más." },
    { at = 10,  name = "Veterano",          icon = "Interface\\Icons\\INV_Shield_06",
      title = "10 mazmorras", text = "%count% mazmorras. El tanque te pide que no corras." },
    { at = 25,  name = "Rompemazmorras",    icon = "Interface\\Icons\\INV_Hammer_05",
      title = "25 mazmorras", text = "%count%. Los jefes finales tiemblan cuando entras." },
    { at = 50,  name = "Señor de las Criptas", icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
      title = "50 mazmorras", text = "%count% mazmorras. Tu casa es una mazmorra." },
    { at = 100, name = "Leyenda de las Profundidades", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Black",
      title = "¡100 mazmorras!", text = "%count%. Los Solfamidas componen canciones sobre tus runs." },
}

---------------------------------------------------------------------------
-- COSITAS: categorías de la pestaña "Cositas" (sale solo el mejor de cada una;
-- la descripción se ve al pasar el ratón). key = dato que se cuenta (no tocar),
-- time = se muestra como tiempo, money = como oro. Se pueden reordenar, renombrar o quitar.
---------------------------------------------------------------------------
T.cositas = {
    { key = "fish",      title = "Chill guy",          desc = "Peces pescados." },
    { key = "boars",     title = "P.E.T.A.",           desc = "Bichos con \"jaba\" en el nombre que te han dado experiencia al morir." },
    { key = "swim",      title = "Como pez en el agua", desc = "Tiempo nadando (sin estar ausente).", time = true },
    { key = "played",    title = "Sudoroso",           desc = "Tiempo jugado (/played de todos los personajes).", time = true },
    { key = "enemyLand", title = "Sediento de sangre", desc = "Tiempo en territorio de la %enemy% (sin contar zonas en disputa ni estando ausente).", time = true },
    { key = "buffs",     title = "Colegón",            desc = "Bufos lanzados a otros jugadores (repetir el mismo al mismo jugador no cuenta)." },
    { key = "respec",    title = "Meta chaser",        desc = "Veces que se ha reiniciado los talentos." },
    -- oculta hasta probar en Forever si hay peluquería (se sigue contando si existe el evento)
    -- { key = "barber",    title = "Estiloso",          desc = "Cambios de peinado en la peluquería." },
    { key = "earned",    title = "Góblin avaro",       desc = "Oro acumulado (todo lo que han ganado sus personajes).", money = true },
    { key = "ah",        title = "Broker",             desc = "Subastas ganadas en la casa de subastas." },
    { key = "deaths",    title = "Críagusanos",        desc = "Veces muerto." },
    { key = "crafted",   title = "Manos callosas",     desc = "Objetos fabricados con profesiones." },
    { key = "group",     title = "FOMO",               desc = "Tiempo en grupo o banda.", time = true },
    { key = "falls",     title = "Paracaidista",       desc = "Muertes por caída." },
    { key = "ghost",     title = "Salvapantallas gris", desc = "Tiempo como fantasma, corriendo de vuelta al cadáver.", time = true },
    { key = "leeroy",    title = "Leeeeroy Jenkins!",  desc = "Veces que ha sido el primero del grupo en morir." },
    { key = "hugs",      title = "Sobón",              desc = "Abrazos, besos, caricias y demás arrumacos (/abrazar, /besar, /acariciar...)." },
    { key = "inspect",   title = "Stalker",            desc = "Veces que ha inspeccionado a otros jugadores." },
    { key = "rolls",     title = "Ludópata",           desc = "/roll tirados." },
    { key = "need",      title = "Ninja",              desc = "Veces que ha elegido Necesidad al repartir botín." },
    { key = "rez",       title = "Ángel de la guarda", desc = "Resurrecciones lanzadas a otros jugadores (repetir a quien aún no se ha levantado no cuenta)." },
    { key = "heal",      title = "Sorakambulancia",    desc = "Curación hecha" },
    { key = "mail",      title = "Cartero",            desc = "Correos enviados." },
    { key = "herbs",     title = "Fumeta",             desc = "Hierbas recogidas." },
    { key = "jumps",     title = "Bunny Hopper",       desc = "Saltos." },
    { key = "session",   title = "Adicto al Monster",  desc = "La sesión de juego seguida más larga (sin desconectarse).", time = true },
}

T.ui = {
    popupButton = "¡A por ello!",
    zoneTitle = "Solfamidas en %zone%",
    zoneText = "Hay compañeros de la guild en tu zona. Marca a quién quieres avisar por susurro:",
    zoneWhisper = "¡Ey! Estoy por %zone%, ¿hacemos grupillo? [SolfaGuild]",
    -- LFS (%dungeon% = mazmorra, %char% = personaje con color y nivel, %who% = quien busca)
    lfsTitle = "Looking for Solfamidas",
    lfsRoleT = "Tanque",
    lfsRoleH = "Sanador",
    lfsRoleD = "DPS",
    lfsOffer = "Los solfamidas se van de expedición a %dungeon%, necesitan apoyo. Tu personaje %char% les iría perfecto, ¿quieres unirte?",
    lfsLeave = "|cffffd200(si aceptas se te echará del grupo en el que estés)|r",
    lfsOtherChar = "|cffffd200(si aceptas tendrás que entrar con %char%; al hacerlo se te echará del grupo en el que estés)|r",
    lfsYes = "Aceptar",
    lfsNo = "Rechazar",
    lfsGoing = "Vas con %who% a %dungeon%. Aceptarás su invitación automáticamente.",
    lfsRelog = "Entra con %char% en menos de %min% min: en cuanto llegues, %who% te invitará.",
    lfsTaken = "Esa plaza ya está cubierta. ¡Gracias de todos modos!",
    lfsCancelled = "La búsqueda del grupo se ha cancelado.",
    eventSoon = "El evento '%title%' empieza en %min% minutos.",
    eventNow = "¡El evento '%title%' empieza AHORA!",
    -- SOS por campeo (%killer% = quien te mata, %who% = jugador, %zone% = zona)
    campAskTitle = "¡Te están campeando!",
    campAskText = "Parece que estás siendo campeado por un sucio %enemy% (%killer%), ¿quieres pedir refuerzos?",
    campAskYes = "Convocar a los solfamidas",
    campAskNo = "Sigo en solitario",
    campCallTitle = "¡Un solfamido pide refuerzos!",
    campCallText = "Un solfamido (%who%) está siendo campeado por un sucio %enemy% y necesita apoyo, en %zone%.",
    campCallLeave = "|cffffd200(si aceptas se te echará del grupo en el que estés)|r",
    campCallYes = "Acudir a la llamada",
    campCallNo = "Ahora no puedo",
    campLeft = "Has salido de tu grupo para montar una banda con los refuerzos.",
    campSent = "Refuerzos pedidos a la guild. Quien acuda recibirá invitación a tu grupo automáticamente.",
    campGoing = "Vas en ayuda de %who%. Aceptarás su invitación automáticamente.",
    campNoJoin = "%who% no ha podido entrar en el grupo tras varios intentos.",
    campComing = "%who% acude a la llamada. Invitándole al grupo...",
}

-- Sustituye marcadores
function SG:Fmt(text, vars)
    if not text then return "" end
    vars = vars or {}
    if not vars.enemy then
        vars.enemy = (UnitFactionGroup("player") == "Alliance") and "Horda" or "Alianza"
    end
    if not vars.name then vars.name = SG.db and SG.db.my.main or SG:MyName() end
    return (text:gsub("%%(%w+)%%", function(k)
        local v = vars[k]
        if v == nil then return "%" .. k .. "%" end
        return tostring(v)
    end))
end
