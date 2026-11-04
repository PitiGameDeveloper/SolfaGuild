-- SolfaGuild - Datos de mazmorras de Forever.
-- id: no cambiarlo (es la clave de lo ya completado por cada personaje).
-- min/max: rango de nivel. Por debajo de min no se puede pedir ni recibir el LFS.
-- bosses: NPC IDs del jefe final (al morir dentro de la instancia cuenta como
-- completada). Vacío = aún no se sabe, así que esa mazmorra no se marca nunca.
-- color: fondo de la tarjeta si el juego no da imagen. art = true: hay imagen
-- propia en Media\Dungeons\<id>.tga.
-- >>> Niveles, nombres y jefes por confirmar: ver el README <<<

local _, ns = ...
local SG = ns.SG

SG.Dungeons = {
    { id = "rfc",    name = "Sima Ígnea", en = "Ragefire Chasm", min = 13, max = 18, bosses = { 11519, 11520 }, color = { 0.55, 0.16, 0.05 } },
    { id = "thanes", name = "Salón de los Thanes", en = "Hall of Thanes", min = 13, max = 20, bosses = { 261319 }, color = { 0.45, 0.32, 0.16 } },
    { id = "ruins",  name = "Ruinas de Lordaeron", en = "Ruins of Lordaeron", min = 15, max = 22, bosses = { 250657 }, color = { 0.22, 0.32, 0.26 } },
    { id = "wc",     name = "Cuevas de los Lamentos", en = "Wailing Caverns", min = 15, max = 24, bosses = { 3654 }, color = { 0.10, 0.36, 0.22 } },
    { id = "vc",     name = "Las Minas de la Muerte", en = "Deadmines", min = 17, max = 26, bosses = { 639 }, color = { 0.13, 0.36, 0.42 } },
    { id = "sfk",    name = "Castillo de Colmillo Oscuro", en = "Shadowfang Keep", min = 20, max = 30, bosses = { 4275 }, color = { 0.18, 0.24, 0.20 } },
    { id = "bfd",    name = "Cavernas de Brazanegra", en = "Blackfathom Deeps", min = 24, max = 32, bosses = { 4829 }, color = { 0.08, 0.20, 0.38 } },
    { id = "stocks", name = "Las Mazmorras", en = "Stockade", min = 24, max = 32, bosses = { 1716 }, color = { 0.28, 0.28, 0.30 } },
    { id = "excav",  name = "Sitio de Excavación: Los Humedales", en = "Excavation Site", min = 24, max = 29, bosses = { 260326 }, color = { 0.36, 0.30, 0.14 } },
    { id = "dalaran", name = "Ciudad de Dalaran", en = "City of Dalaran", min = 28, max = 33, bosses = { 247032, 246020 }, color = { 0.34, 0.20, 0.48 } },
    { id = "gnomer", name = "Gnomeregan", en = "Gnomeregan", min = 29, max = 38, bosses = { 7800 }, color = { 0.20, 0.34, 0.38 } },
    { id = "rfk",    name = "Horado Rajacieno", en = "Razorfen Kraul", min = 29, max = 38, bosses = { 4421 }, color = { 0.40, 0.24, 0.10 } },
    { id = "smgy",   name = "Monasterio Escarlata: Cementerio", en = "Scarlet Monastery", min = 26, max = 36, bosses = { 4543 }, color = { 0.42, 0.08, 0.08 } },
    { id = "smlib",  name = "Monasterio Escarlata: Biblioteca", en = "Scarlet Monastery", min = 29, max = 39, bosses = { 6487 }, color = { 0.42, 0.08, 0.08 } },
    { id = "smarm",  name = "Monasterio Escarlata: Armería", en = "Scarlet Monastery", min = 32, max = 42, bosses = { 3975 }, color = { 0.42, 0.08, 0.08 } },
    { id = "smcath", name = "Monasterio Escarlata: Catedral", en = "Scarlet Monastery", min = 35, max = 45, bosses = { 3977 }, color = { 0.42, 0.08, 0.08 } },
    { id = "drowned", name = "La Ciudad Sumergida", en = "The Drowned City", min = 35, max = 40, bosses = { 270886 }, color = { 0.06, 0.32, 0.36 } },
    { id = "rfd",    name = "Zahúrda Rajacieno", en = "Razorfen Downs", min = 37, max = 46, bosses = { 7358 }, color = { 0.34, 0.26, 0.20 } },
    { id = "krol",   name = "Bastión de Krol'dok", en = "Krol'dok Stronghold", min = 40, max = 45, bosses = {}, color = { 0.30, 0.34, 0.14 } },
    { id = "ulda",   name = "Uldaman", en = "Uldaman", min = 41, max = 51, bosses = { 2748 }, color = { 0.42, 0.32, 0.18 } },
    { id = "zf",     name = "Zul'Farrak", en = "Zul'Farrak", min = 44, max = 54, bosses = { 7267 }, color = { 0.50, 0.36, 0.12 } },
    { id = "mara",   name = "Maraudon", en = "Maraudon", min = 46, max = 55, bosses = { 12201 }, color = { 0.26, 0.20, 0.42 } },
    { id = "alcaz",  name = "Prisión de Alcaz", en = "Alcaz", min = 48, max = 53, bosses = {}, color = { 0.24, 0.30, 0.30 } },
    { id = "st",     name = "Templo de Atal'Hakkar", en = "Sunken Temple", min = 50, max = 60, bosses = { 5709 }, color = { 0.10, 0.30, 0.20 } },
    { id = "brd",    name = "Profundidades de Roca Negra", en = "Blackrock Depths", min = 52, max = 60, bosses = { 9019 }, color = { 0.46, 0.14, 0.06 } },
    { id = "lbrs",   name = "Cumbre de Roca Negra Inferior", en = "Lower Blackrock Spire", min = 55, max = 60, bosses = { 9568 }, color = { 0.36, 0.14, 0.10 } },
    { id = "ubrs",   name = "Cumbre de Roca Negra Superior", en = "Upper Blackrock Spire", min = 55, max = 60, bosses = { 10363 }, color = { 0.40, 0.10, 0.12 } },
    { id = "dme",    name = "La Masacre: Este", en = "Dire Maul", min = 55, max = 60, bosses = { 11492 }, color = { 0.16, 0.30, 0.14 } },
    { id = "blackmaw", name = "Fuerte Faucenegra", en = "Blackmaw Hold", min = 55, max = 60, bosses = {}, color = { 0.18, 0.18, 0.24 } },
    { id = "dmw",    name = "La Masacre: Oeste", en = "Dire Maul", min = 57, max = 60, bosses = { 11486 }, color = { 0.16, 0.30, 0.14 } },
    { id = "dmn",    name = "La Masacre: Norte", en = "Dire Maul", min = 57, max = 60, bosses = { 11501 }, color = { 0.16, 0.30, 0.14 } },
    { id = "shaper", name = "La Terraza del Creador", en = "Shaper", min = 58, max = 60, bosses = {}, color = { 0.34, 0.36, 0.16 } },
    { id = "stratl", name = "Stratholme (Vivos)", en = "Stratholme", min = 58, max = 60, bosses = { 10813 }, color = { 0.34, 0.16, 0.16 } },
    { id = "stratu", name = "Stratholme (No-muertos)", en = "Stratholme", min = 58, max = 60, bosses = { 10440 }, color = { 0.20, 0.24, 0.28 } },
    { id = "scholo", name = "Scholomance", en = "Scholomance", min = 58, max = 60, bosses = { 1853 }, color = { 0.24, 0.18, 0.30 } },
}

SG.DungeonById = {}
SG.DungeonByBoss = {}
for _, d in ipairs(SG.Dungeons) do
    SG.DungeonById[d.id] = d
    for _, npc in ipairs(d.bosses) do SG.DungeonByBoss[npc] = d end
end

-- Funciones que puede hacer cada clase. Una clase que no esté aquí solo hace DPS.
SG.ClassRoles = {
    WARRIOR = { T = true, D = true },
    PALADIN = { T = true, H = true, D = true },
    DRUID   = { T = true, H = true, D = true },
    PRIEST  = { H = true, D = true },
    SHAMAN  = { H = true, D = true },
    ROGUE   = { D = true }, MAGE = { D = true }, WARLOCK = { D = true }, HUNTER = { D = true },
}
