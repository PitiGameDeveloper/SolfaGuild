# Qué probar en Forever

Todo lo que el addon da por supuesto y solo se puede comprobar en el juego. La simulación de `tests/` prueba la lógica, pero no esto. Se ha ordenado para probar primero lo que hace falta para lo demás.

Para casi todo hacen falta **dos jugadores de la guild conectados con el addon**, y para el PvP, además, enemigos.

Antes de empezar, activa `/sg debug`: enseña en el chat cada muerte honorable. Si algo falla, el addon avisa en el chat y guarda los errores en `SolfaGuildDB.errors` (`WTF\Account\<cuenta>\SavedVariables\SolfaGuild.lua`).

## 1. Lo básico (si falla, falla casi todo)
- [ ] Al entrar **no sale ningún aviso de "addon bloqueado"** ni errores en el chat.
- [ ] `/dump (select(4, GetBuildInfo()))` da `16001`, el número que lleva el `.toc`.
- [ ] WowUp reconoce la carpeta como cliente *Forever* e instala y actualiza desde la URL.
- [ ] **Nombres con apellido**: dos jugadores se ven conectados y se reconocen en los rankings. Si no, mirar el formato del remitente de los mensajes (`SG:Short`, en `Core.lua`).
- [ ] **Mensajes entre jugadores**: las estadísticas de uno le llegan al otro, y los susurros de addon también llegan (`SG:Target`).
- [ ] Se reconoce al GM: solo él y sus alters ven la pestaña *GM*, y sus ajustes llegan a los demás.
- [ ] Un personaje que ya hubiera entrado con una versión anterior conserva sus datos al entrar.
- [ ] **Personaje borrado**: crear un alter, meterlo en la guild, entrar con él y borrarlo. Desaparece de tu lista y de la de los demás en un par de minutos. Mirar que un alter desconectado que sigue en la guild no desaparece nunca (si pasara, ver cómo da `GetGuildRosterInfo` la lista con los desconectados).
- [ ] **Mismo nombre**: borrar ese alter y crear otro con el mismo nombre. Empieza de cero, y el LFS y los rankings van bien.
- [ ] **Cambio de reino**: si Forever tiene traslados, un personaje trasladado conserva sus datos (`UnitGUID` cambia de reino).
- [ ] **Perfil cada minuto**: lo que hace un jugador le llega al otro en un minuto como mucho, sin tirones en banda.
- [ ] Todas las pestañas se abren y **se ven bien**: nunca se ha visto ninguna ventana dibujada.

## 2. Asesinatos PvP
- [ ] Una muerte honorable en mundo abierto suma **1 kill** (no 0 ni 2).
- [ ] Estar parado junto a una pelea ajena no suma nada.
- [ ] En un campo de batalla o una mazmorra no suma.
- [ ] Un nivel 60 que mata a un nivel 20 no suma.
- [ ] Un nivel 60 ayudando a un nivel 20: al 60 no le cuenta, y no sale como asesinato en grupo. Ver si al 20 le cuenta o no (lo decide el juego).
- [ ] La kill suma en su zona, en el escalafón total y en el semanal.
- [ ] La primera kill de la cuenta saca la carta, y su botón **Ver PvP** abre el addon en la pestaña PvP. Las siguientes no sacan nada. El texto cabe en la carta.

## 3. Asesinatos en grupo
- [ ] **Clave**: dos jugadores en la misma pelea ven con `/sg debug` el **mismo identificador** (`Muerte honorable. Identificador: Player-...`).
- [ ] Si sale `ninguno`: Forever no da el identificador de jugadores en `UNIT_DIED` ni `PARTY_KILL`, y solo queda la vía de reserva (mismo grupo o mismo objetivo).
- [ ] 2v2: cada muerte sale como un asesinato en grupo.
- [ ] Otro jugador que mata a otro enemigo a la vez en un 1v1 no se junta con ellos.
- [ ] Un Skyborne de tu bando que muere cerca no se apunta como muerto (`UnitTokenFromGUID`). `RACE_FACTION`, en `Modules/PvP.lua`, tiene todas las razas de bando fijo.

## 4. SOS por campeo
- [ ] Morir 2 veces a manos de un jugador enemigo en 10 minutos abre la ventana y nombra al asesino (`C_DeathRecap.GetRecapEvents`).
- [ ] Morir a manos de un monstruo no cuenta.
- [ ] Liberar el espíritu no cuenta como otra muerte.
- [ ] Al convocar, a los demás les llega el aviso con tu zona.
- [ ] Quien acude sale de su grupo y entra **sin pulsar nada más** (`LeaveParty`, `InviteUnit`, `AcceptGroup`). Si el juego pide clic, hay que cambiar el flujo.
- [ ] Yendo solo: ver si el juego deja tener más de 4 invitaciones pendientes (si no, el addon las repite al pasar a banda).
- [ ] El grupo pasa bien a banda (`ConvertToRaid`).

## 5. LFS
- [ ] `/sg lfs` enseña la oferta de prueba: el texto cabe y se ven los botones de radio (si `UIRadioButtonTemplate` no existe, salen casillas). Cada uno lleva su icono pequeño de tanque, sanador o DPS (atlas `UI-LFG-RoleIcon-*` o, si no está, los iconos 134952, 136041 y 132223), sin pisar el nombre.
- [ ] **Imágenes de las tarjetas**: son las pantallas de carga del juego (`LOADING_SCREEN` en `Data/Dungeons.lua`). Comprobar que salen, que no se ven estiradas (recorte en `fillCard`, `UI/LFS.lua`) y que cada una es la de su mazmorra. Dalaran, La Ciudad Sumergida, Krol'dok, Alcaz, Faucenegra y La Terraza del Creador salen de color: falta su identificador.
- [ ] La rejilla no deja huecos: la primera mazmorra va en la fila 1, columna 1.
- [ ] La lista se abre arriba del todo: primero las disponibles y luego las bloqueadas, cada grupo de mayor a menor nivel.
- [ ] **Ventana de búsqueda**: salen los iconos del LFG (atlas `UI-LFG-RoleIcon-*`, los usa la interfaz de Forever), nítidos y con el brillo alrededor al encenderlos. Si no estuvieran, salen los iconos 134952, 136041 y 132223 recortados en redondo y con aro dorado: comprobarlo también en Classic Era. En los tres círculos el clic izquierdo añade y el derecho quita (tanque y sanador, 0 o 1; DPS, de 0 a 3). Con tanque, sanador y 3 DPS se apaga "Buscar".
- [ ] **Ventana principal**: "SolfaGuild" sale a 32 px de la izquierda; a 32 px de la derecha, sin pisar el botón de cerrar, el número de conectados de la guild y el icono de `Media\silbando.tga`. El número cambia cuando alguien entra o sale. Al pasar el ratón sale el tooltip "Solfamiders conectados", y la ventana se sigue pudiendo arrastrar desde el resto de la barra.
- [ ] El tick verde sale en las mazmorras completadas.
- [ ] La búsqueda llega a quien toca, en el orden correcto, y nunca a quien no llega al nivel.
- [ ] Quien acepta sale de su grupo y entra **sin pulsar nada más**.
- [ ] Oferta con un alter: al entrar con él dentro de los 5 min, le invitan solo.
- [ ] Buscando solo 2 DPS, con dos colegas conectados **fuera de tu grupo**, les salen las dos ofertas a la vez, también justo después de entrar (cuando más perfiles se envían). Quien ya va en tu grupo no recibe oferta.
- [ ] **Resultado de la búsqueda**: durante la búsqueda se ve cómo va cada persona (pensándoselo, ha aceptado, ha rechazado, no ha contestado, está ocupado, en el grupo) y los textos caben. Al acabar, la ventana enseña "¡Grupo completo!" o "No queda nadie a quien avisar" con lo que falta; si estaba cerrada, se abre sola y suena. "Nueva búsqueda" vuelve al formulario con lo que falta ya marcado.
- [ ] Los mensajes llegan también si hay restricción de chat (`C_ChatInfo.InChatMessagingLockdown`).
- [ ] Tamaño de grupo: se asume 5 en todas (`MAX_GROUP`). Una guía dice 10 en Cumbre de Roca Negra Superior.
- [ ] Funciones por clase (`SG.ClassRoles`, en `Data/Dungeons.lua`): son las de Classic. Ver si alguna clase puede tanquear o curar además.

## 6. Mazmorras (`Data/Dungeons.lua`)
- [ ] Al morir el jefe final dentro, la mazmorra cuenta **una vez** (`UNIT_DIED`, `PARTY_KILL`; `IsInInstance()` debe devolver `party` o `raid`).
- [ ] **Sin `UNIT_DIED` no contaba ninguna** (11-nov: listas vacías en Forever). Luego, con `ENCOUNTER_END` y el jefe en `boss1..5`
  o en el objetivo, **tampoco** (11-nov): dentro no hay `boss1` y el objetivo no da el GUID. Ahora el jefe final se reconoce por el
  **nombre del encuentro** (`FINAL_NAMES` en `Data/Dungeons.lua`, en español y en inglés). Con `/sg debug` sale
  "Fin de encuentro: id, nombre, bien, mazmorra" al matar cada jefe: comprobar que el final da su mazmorra (no "?"). Si sale "?",
  apuntar el nombre exacto que sale y añadirlo a `FINAL_NAMES`. Los nombres en español son de AtlasLoot/ForeverDungeonJournal; los
  menos seguros: *Durgen Martillo Funesto/Fúnebre*, *Señor supremo Vermiothalak*, y Krol'dok y Faucenegra, que aún no tienen ninguno.
- [ ] **Aviso de primera mazmorra**: al subir al nivel de la primera mazmorra (el `min` más bajo de `Data/Dungeons.lua`, ahora 13) sale la carta con su título entero en la ventana (`PLAYER_LEVEL_UP` debe dar el nivel), y **Ver PvE** abre la pestaña PvE. Comprobar que ese nivel es de verdad el mínimo para entrar.
- [ ] **Mazmorras más completadas y grupos**: los Solfamidas que van juntos suman **una** completación y salen como grupo; por separado, una cada uno. Comprobar que dentro de la instancia el juego da los nombres del grupo (`UnitName`, sin valores ocultos); si no, cuentan por separado. Quien está en el grupo pero fuera de la instancia también sale en el grupo.
- [ ] **Niveles**: las guías no coinciden. Las 6 de la captura van con sus niveles y las demás con los de AtlasLootClassic y NeedRoll. Se usa un solo rango; el nivel real para entrar suele ser menor.
- [ ] **Jefes sin NPC ID** (aún no se marcan como completadas): Bastión de Krol'dok, Prisión de Alcaz (Blazeroar), Fuerte Faucenegra y La Terraza del Creador (Nanaya).
- [ ] **Jefes sin confirmar**: La Ciudad Sumergida (Min'Loth) y Ciudad de Dalaran (valen Lyn y la Sombra del Archimago).
- [ ] **Nombres en español**: *Salón de los Thanes* y *Sitio de Excavación: Los Humedales* son una suposición; el resto de las nuevas salen de la traducción de Attune.

## 7. Cositas (`Modules/Cositas.lua`)
- [ ] **Sorakambulancia**: suma al salir de combate (`C_DamageMeter`), también en mazmorra. Ver si incluye curarte a ti mismo o la curación que sobra.
- [ ] **Paracaidista**: morir de una caída suma; ahogarse, la fatiga o la lava no (`environmentalType` debe ser `Falling`).
- [ ] **Ángel de la guarda**: resucitar suma, y repetir a quien aún no se ha levantado no.
- [ ] **Buffon**: un bufo a otro suma, repetirlo al mismo no, y a otro jugador sí (espera de 5 min).
- [ ] **Listas de hechizos** (`REZ_SPELLS`, `BUFF_SPELLS`): los IDs son correctos. Añadir los propios de Forever, como los de los Skyborne.
- [ ] **P.E.T.A.**: un bicho con "jaba" en el nombre que da experiencia suma (`COMBATLOG_XPGAIN_FIRSTPERSON` debe existir y encajar).
- [ ] **Críagusanos**: cada muerte suma una sola vez, también al liberar el espíritu.
- [ ] **Estiloso**: está oculta (comentada en `T.cositas` de `Data/Texts.lua`). Si hay peluquería y salta `BARBER_SHOP_APPEARANCE_APPLIED`, se descomenta; si no hay, se borra.
- [ ] **Meta chaser**: cuenta `ConfirmTalentWipe`. Si Forever reinicia talentos de otra forma, hay que contarlo de otra manera.
- [ ] **Broker** y **Manos callosas**: siguen existiendo `ERR_AUCTION_WON_S`, `LOOT_ITEM_CREATED_SELF` y `LOOT_ITEM_CREATED_SELF_MULTIPLE`.
- [ ] **Fumeta**: recoger hierbas suma (hechizo 2366, se compara por nombre).
- [ ] **Camper**: suma en territorio enemigo. 11-nov: en Loch Modan (Horda) no sumaba, así que el juego no daba `hostile`. Ahora
  también mira la lista `FACTION_LAND` de `Modules/Cositas.lua` (mapas de Classic). Comprobar que suma en Loch Modan y que
  `C_Map.GetBestMapForUnit("player")` da los mismos números que Classic (1432 Loch Modan). Si Forever tiene zonas nuevas de una
  facción, añadirlas a la lista. En zonas en disputa (Los Humedales) no suma. Zonas nuevas de Forever, que según las guías no
  son de ninguna facción y por eso no están en la lista: Monte Hyjal (2482) y Riverglades (2548), en disputa; Isla de Zephras
  (2521), inicio de los Cielonatos de las dos facciones. Al entrar en cada una, comprobar que el juego dice "en disputa" (o
  "santuario"); si alguna dice "Territorio de la Alianza/Horda", añadirla a `FACTION_LAND`.
- [ ] **Bunny Hopper**, **Ludópata**, **Ninja**, **Stalker** y **Sobón**: suman (`JumpOrAscendStart`, `RandomRoll`, `RollOnLoot`, `InspectUnit`, `C_ChatInfo.PerformEmote`). Si una de esas funciones no existe, la categoría se queda a 0 sin dar error.
- [ ] **Solfamicida**: ganar un duelo a otro Solfamida suma (`CHAT_MSG_SYSTEM` con `DUEL_WINNER_KNOCKOUT` y `DUEL_WINNER_RETREAT`), también si huye, uno cada 2 min; perder, ganar a alguien de fuera o un duelo ajeno, no. Probar también un duelo a muerte: la línea puede ser otra y entonces no sumaría.
- [ ] **Pasmao** y **Pasmao fit**: en Orgrimmar (mapa 1454, también en sus zonas interiores), parado, también en montura o ausente (AFK), suma a Pasmao, y moviéndote, a pie o en montura, a Pasmao fit (`GetUnitSpeed`).
- [ ] **No pilló el vuelo** (a pie, en montura o por el suelo) y **Va flying** (`IsFlying()` o taxi, `UnitOnTaxi`): suman yardas en horizontal con `C_Map.GetPlayerMapPosition` + `C_Map.GetWorldPosFromMapPos`. Comprobar: que cada una suma solo en su caso (volando no suma a pie, a pie no suma a volando); que el taxi suma a la de volar; que caer (`IsFalling`) y nadar no suman a ninguna; que una montura terrestre suma a pie; que un movimiento de menos de 10 yardas (spam de teclas) no suma; y que las coordenadas no vienen ocultas (`issecretvalue`) en Forever (si vienen ocultas, no suma nada).
- [ ] **Topes contra macros**: `/hug` con otro jugador de objetivo suma; sin objetivo, a un PNJ o a ti, no. Repetirlo no suma hasta pasados 2 min, tampoco a otra persona; un `/reload` no lo reinicia. `/hug Fulano` solo suma si lo tienes de objetivo o va en tu grupo. Comprobar que al clicar en un jugador para inspeccionarlo cuenta (Stalker), que `/roll` suma uno por minuto y el correo uno cada 30 s.
- [ ] Nota musical en los susurros de compañeros y aviso de invitación (`ChatFrameUtil.AddMessageEventFilter`, `StaticPopup_Resize`).

## 8. Mapa de la guild (`Modules/GuildMap.lua`)
- [ ] Al abrir el mapa, en unos segundos sale cada Solfamida conectado como un punto **del color de su clase**, con el chamán en azul (`Media/pin.tga`, también en Classic Era). Tú no sales.
- [ ] Al pasar el ratón sale su nombre con apellido. Si hay varios juntos, salen todos.
- [ ] **Clics**: pinchar encima de un punto sigue cambiando de zona en el mapa (`SetMouseClickEnabled`).
- [ ] **Otros mapas**: sale bien colocado en su zona, en la zona de al lado (si cae dentro), en el continente y en el mapa del mundo; en otro continente no sale. Comprobar sobre todo el mapa del mundo (`GetMapPosFromWorldPos` y, si no da nada, `GetMapRectOnMap`). También en Orgrimmar viendo Durotar, y al revés.
- [ ] El punto mide siempre lo mismo y no se descoloca al acercar el mapa ni con el mapa grande, y queda por encima de lo demás (`PIN_FRAME_LEVEL_AREA_POI`).
- [ ] Se mueve al moverse el otro jugador (cada 4 s como mucho). Al entrar en una instancia desaparece y al desconectarse también (como mucho 50 s).
- [ ] **Sin tirones ni mensajes de más**: con el mapa cerrado no sale ningún mensaje `POS`, y en banda tampoco (`/sg debug` no lo enseña: mirarlo con un addon de mensajes o por el rendimiento).
- [ ] Un compañero de grupo sale dos veces, con el punto del juego y el nuestro. Ver si queda mal y si el tooltip del juego sale bien.
- [ ] Con la pestaña de MuddyBoots abierta en el mapa, ese addon oculta lo de otros addons: ver que al volver a la otra pestaña vuelven a salir los puntos.
- [ ] Apagar *Mapa de la guild* en la pestaña GM quita los puntos a todos.

## 9. Otros
- [ ] Semana: el escalafón semanal se reinicia con el reinicio del juego (`C_DateAndTime.GetSecondsUntilWeeklyReset`; si no existe, se usa el miércoles a las 05:00 del PC).
- [ ] Eventos: crearlos, que lleguen a los demás y que salte el aviso.
- [ ] Crear un evento en el calendario del WoW (depende de la API del cliente y de los permisos de guild).
