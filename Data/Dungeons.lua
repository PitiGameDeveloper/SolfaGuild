-- SolfaGuild - Datos de mazmorras (Classic, punto de vista Horda)
-- min/max: rango de nivel recomendado. unlock: nivel en el que (aprox.) ya tienes
-- disponibles las misiones de la mazmorra. bosses: NPC IDs del jefe final
-- (al morir dentro de la instancia cuenta como "completada").
-- quests: lista de misiones. x/y/map son opcionales (si están y tienes TomTom
-- se crea un waypoint). >>> DATOS A COMPLETAR / REVISAR EN FOREVER <<<

local _, ns = ...
local SG = ns.SG

SG.Dungeons = {
    { id = "rfc", name = "Sima Ígnea", min = 13, max = 18, unlock = 13, bosses = { 11519, 11520 },
      quests = {
        { name = "Poniendo a prueba al enemigo", giver = "Rahauro (Cima del Trueno)" },
        { name = "Enemigos ocultos", giver = "Thrall (Orgrimmar)" },
        { name = "En busca de la cartera perdida", giver = "Rahauro (Cima del Trueno)" },
        { name = "Matar a la bestia", giver = "Neeru Filoardiente (Orgrimmar)" },
      } },
    { id = "wc", name = "Cuevas de los Lamentos", min = 17, max = 24, unlock = 17, bosses = { 3654 },
      quests = {
        { name = "Flor de serpiente", giver = "Boticario Zamah (Cima del Trueno)" },
        { name = "Líderes del Colmillo", giver = "Nara Melena Salvaje (Cima del Trueno)" },
        { name = "Pieles descarriadas", giver = "Nalpak (entrada de las cuevas)" },
        { name = "Problemas en los muelles", giver = "Operador de grúa Bigglefuzz (Trinquete)" },
        { name = "Bebidas inteligentes", giver = "Mebok Mizzyrix (Trinquete)" },
      } },
    { id = "sfk", name = "Castillo de Colmillo Oscuro", min = 22, max = 30, unlock = 22, bosses = { 4275 },
      quests = {
        { name = "Mortacechadores en Colmillo Oscuro", giver = "Alto ejecutor Hadrec (Sepulcro)" },
        { name = "El libro de Ur", giver = "Guardián Bel'dugur (Entrañas)" },
        { name = "Arugal debe morir", giver = "Dalar Tejealba (Sepulcro)" },
      } },
    { id = "bfd", name = "Cavernas de Brazanegra", min = 24, max = 32, unlock = 24, bosses = { 4829 },
      quests = {
        { name = "La esencia de Aku'Mai", giver = "Je'neu Sancrea (Zoram'gar)" },
        { name = "Entre las ruinas", giver = "Je'neu Sancrea (Zoram'gar)" },
        { name = "Maldad en Brazanegra", giver = "Bashana Runatotem (Cima del Trueno)" },
      } },
    { id = "gnomer", name = "Gnomeregan", min = 29, max = 38, unlock = 29, bosses = { 7800 }, quests = {} },
    { id = "rfk", name = "Horado Rajacieno", min = 29, max = 38, unlock = 29, bosses = { 4421 }, quests = {} },
    { id = "smgy", name = "Monasterio Escarlata: Cementerio", min = 28, max = 38, unlock = 28, bosses = { 4543 }, quests = {} },
    { id = "smlib", name = "Monasterio Escarlata: Biblioteca", min = 29, max = 39, unlock = 33, bosses = { 6487 }, quests = {} },
    { id = "smarm", name = "Monasterio Escarlata: Armería", min = 32, max = 42, unlock = 33, bosses = { 3975 }, quests = {} },
    { id = "smcath", name = "Monasterio Escarlata: Catedral", min = 35, max = 45, unlock = 37, bosses = { 3977 }, quests = {} },
    { id = "rfd", name = "Zahúrda Rajacieno", min = 37, max = 46, unlock = 37, bosses = { 7358 }, quests = {} },
    { id = "ulda", name = "Uldaman", min = 41, max = 51, unlock = 41, bosses = { 2748 }, quests = {} },
    { id = "zf", name = "Zul'Farrak", min = 44, max = 54, unlock = 44, bosses = { 7267 }, quests = {} },
    { id = "mara", name = "Maraudon", min = 46, max = 55, unlock = 46, bosses = { 12201 }, quests = {} },
    { id = "st", name = "Templo de Atal'Hakkar", min = 50, max = 60, unlock = 50, bosses = { 5709 }, quests = {} },
    { id = "brd", name = "Profundidades de Roca Negra", min = 52, max = 60, unlock = 52, bosses = { 9019 }, quests = {} },
    { id = "lbrs", name = "Cumbre de Roca Negra Inferior", min = 55, max = 60, unlock = 55, bosses = { 9568 }, quests = {} },
    { id = "dme", name = "La Masacre: Este", min = 55, max = 60, unlock = 55, bosses = { 11492 }, quests = {} },
    { id = "dmw", name = "La Masacre: Oeste", min = 57, max = 60, unlock = 57, bosses = { 11486 }, quests = {} },
    { id = "dmn", name = "La Masacre: Norte", min = 57, max = 60, unlock = 57, bosses = { 11501 }, quests = {} },
    { id = "stratl", name = "Stratholme (Vivos)", min = 58, max = 60, unlock = 58, bosses = { 10813 }, quests = {} },
    { id = "stratu", name = "Stratholme (No-muertos)", min = 58, max = 60, unlock = 58, bosses = { 10440 }, quests = {} },
    { id = "scholo", name = "Scholomance", min = 58, max = 60, unlock = 58, bosses = { 1853 }, quests = {} },
    { id = "ubrs", name = "Cumbre de Roca Negra Superior", min = 58, max = 60, unlock = 58, bosses = { 10363 }, quests = {} },
}

SG.DungeonById = {}
SG.DungeonByBoss = {}
for _, d in ipairs(SG.Dungeons) do
    SG.DungeonById[d.id] = d
    for _, npc in ipairs(d.bosses) do SG.DungeonByBoss[npc] = d end
end
