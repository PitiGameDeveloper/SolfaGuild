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
- [ ] Todas las pestañas se abren y **se ven bien**: nunca se ha visto ninguna ventana dibujada.

## 2. Asesinatos PvP
- [ ] Una muerte honorable en mundo abierto suma **1 kill** (no 0 ni 2).
- [ ] Estar parado junto a una pelea ajena no suma nada.
- [ ] En un campo de batalla o una mazmorra no suma.
- [ ] Un nivel 60 que mata a un nivel 20 no suma.
- [ ] Un nivel 60 ayudando a un nivel 20: al 60 no le cuenta, y no sale como asesinato en grupo. Ver si al 20 le cuenta o no (lo decide el juego).
- [ ] La kill suma en su zona, en el escalafón total y en el semanal.

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
- [ ] `/sg lfs` enseña la oferta de prueba: el texto cabe y se ven los botones de radio (si `UIRadioButtonTemplate` no existe, salen casillas).
- [ ] **Imágenes de las tarjetas**: son las pantallas de carga del juego (`LOADING_SCREEN` en `Data/Dungeons.lua`). Comprobar que salen, que no se ven estiradas (recorte en `fillCard`, `UI/LFS.lua`) y que cada una es la de su mazmorra. Dalaran, La Ciudad Sumergida, Krol'dok, Alcaz, Faucenegra y La Terraza del Creador salen de color: falta su identificador.
- [ ] La rejilla no deja huecos: la primera mazmorra va en la fila 1, columna 1.
- [ ] La lista se abre arriba del todo: primero las disponibles y luego las bloqueadas, cada grupo de mayor a menor nivel.
- [ ] **Ventana de búsqueda**: salen los iconos del LFG (atlas `UI-LFG-RoleIcon-*`, los usa la interfaz de Forever), nítidos y con el brillo alrededor al encenderlos. Si no estuvieran, salen los iconos 134952, 136041 y 132223 recortados en redondo y con aro dorado: comprobarlo también en Classic Era. En los tres círculos el clic izquierdo añade y el derecho quita (tanque y sanador, 0 o 1; DPS, de 0 a 3). Con tanque, sanador y 3 DPS se apaga "Buscar".
- [ ] **Ventana principal**: "SolfaGuild" sale a 32 px de la izquierda; a 32 px de la derecha, sin pisar el botón de cerrar, el número de conectados de la guild y el icono de `Media\silbando.tga`. El número cambia cuando alguien entra o sale. Al pasar el ratón sale el tooltip "Solfamiders conectados", y la ventana se sigue pudiendo arrastrar desde el resto de la barra.
- [ ] El tick verde sale en las mazmorras completadas.
- [ ] La búsqueda llega a quien toca, en el orden correcto, y nunca a quien no llega al nivel.
- [ ] Quien acepta sale de su grupo y entra **sin pulsar nada más**.
- [ ] Oferta con un alter: al entrar con él dentro de los 5 min, le invitan solo.
- [ ] Faltando solo DPS salen dos ofertas a la vez.
- [ ] Los mensajes llegan también si hay restricción de chat (`C_ChatInfo.InChatMessagingLockdown`).
- [ ] Tamaño de grupo: se asume 5 en todas (`MAX_GROUP`). Una guía dice 10 en Cumbre de Roca Negra Superior.
- [ ] Funciones por clase (`SG.ClassRoles`, en `Data/Dungeons.lua`): son las de Classic. Ver si alguna clase puede tanquear o curar además.

## 6. Mazmorras (`Data/Dungeons.lua`)
- [ ] Al morir el jefe final dentro, la mazmorra cuenta **una vez** (`UNIT_DIED`, `PARTY_KILL`; `IsInInstance()` debe devolver `party` o `raid`).
- [ ] **Mazmorras más completadas y grupos**: los Solfamidas que van juntos suman **una** completación y salen como grupo; por separado, una cada uno. Comprobar que dentro de la instancia el juego da los nombres del grupo (`UnitName`, sin valores ocultos); si no, cuentan por separado. Quien está en el grupo pero fuera de la instancia también sale en el grupo.
- [ ] **Niveles**: las guías no coinciden. Las 6 de la captura van con sus niveles y las demás con los de AtlasLootClassic y NeedRoll. Se usa un solo rango; el nivel real para entrar suele ser menor.
- [ ] **Jefes sin NPC ID** (aún no se marcan como completadas): Bastión de Krol'dok, Prisión de Alcaz (Blazeroar), Fuerte Faucenegra y La Terraza del Creador (Nanaya).
- [ ] **Jefes sin confirmar**: La Ciudad Sumergida (Min'Loth) y Ciudad de Dalaran (valen Lyn y la Sombra del Archimago).
- [ ] **Nombres en español**: *Salón de los Thanes* y *Sitio de Excavación: Los Humedales* son una suposición; el resto de las nuevas salen de la traducción de Attune.

## 7. Cositas (`Modules/Cositas.lua`)
- [ ] **Sorakambulancia**: suma al salir de combate (`C_DamageMeter`), también en mazmorra. Ver si incluye curarte a ti mismo o la curación que sobra.
- [ ] **Paracaidista**: morir de una caída suma; ahogarse, la fatiga o la lava no (`environmentalType` debe ser `Falling`).
- [ ] **Ángel de la guarda**: resucitar suma, y repetir a quien aún no se ha levantado no.
- [ ] **Colegón**: un bufo a otro suma, repetirlo al mismo no, y a otro jugador sí (espera de 5 min).
- [ ] **Listas de hechizos** (`REZ_SPELLS`, `BUFF_SPELLS`): los IDs son correctos. Añadir los propios de Forever, como los de los Skyborne.
- [ ] **P.E.T.A.**: un bicho con "jaba" en el nombre que da experiencia suma (`COMBATLOG_XPGAIN_FIRSTPERSON` debe existir y encajar).
- [ ] **Críagusanos**: cada muerte suma una sola vez, también al liberar el espíritu.
- [ ] **Estiloso**: está oculta (comentada en `T.cositas` de `Data/Texts.lua`). Si hay peluquería y salta `BARBER_SHOP_APPEARANCE_APPLIED`, se descomenta; si no hay, se borra.
- [ ] **Meta chaser**: cuenta `ConfirmTalentWipe`. Si Forever reinicia talentos de otra forma, hay que contarlo de otra manera.
- [ ] **Broker** y **Manos callosas**: siguen existiendo `ERR_AUCTION_WON_S`, `LOOT_ITEM_CREATED_SELF` y `LOOT_ITEM_CREATED_SELF_MULTIPLE`.
- [ ] **Fumeta**: recoger hierbas suma (hechizo 2366, se compara por nombre).
- [ ] **Camper**: suma en territorio enemigo (`C_PvP.GetZonePVPInfo` o `GetZonePVPInfo`).
- [ ] **Bunny Hopper**, **Ludópata**, **Ninja**, **Stalker** y **Sobón**: suman (`JumpOrAscendStart`, `RandomRoll`, `RollOnLoot`, `InspectUnit`, `DoEmote`). Si una de esas funciones no existe, la categoría se queda a 0 sin dar error.
- [ ] Nota musical en los susurros de compañeros y aviso de invitación (`ChatFrameUtil.AddMessageEventFilter`, `StaticPopup_Resize`).

## 8. Otros
- [ ] Semana: el escalafón semanal se reinicia con el reinicio del juego (`C_DateAndTime.GetSecondsUntilWeeklyReset`; si no existe, se usa el miércoles a las 05:00 del PC).
- [ ] Eventos: crearlos, que lleguen a los demás y que salte el aviso.
- [ ] Crear un evento en el calendario del WoW (depende de la API del cliente y de los permisos de guild).
