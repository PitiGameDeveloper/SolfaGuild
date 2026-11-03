# SolfaGuild

Addon de guild para **Los Solfamidas** (WoW Forever, Horda). Es para pasarlo bien: rankings, rangos de PvP propios, hitos de oro, eventos y algún detalle social.

> **IMPORTANTE: este addon es para WoW Forever (sale el 4 de noviembre de 2026).** Classic Era solo se usa para probarlo antes de que salga. Todo lo que se implemente tiene que funcionar en Forever; lo que pueda cambiar entre los dos clientes se apunta en *Pendiente / por revisar en Forever*. Más detalles en `CLAUDE.md`.

## Instalación
### Con WowUp (recomendado)
No hace falta cuenta de GitHub. En WowUp, con el cliente de Forever (o Classic Era) seleccionado: *Obtener addons → Instalar desde URL* → `https://github.com/PitiGameDeveloper/SolfaGuild`.

WowUp avisará de las actualizaciones como con cualquier otro addon.

**Publicar una versión nueva** (GM): `git tag v0.1.1 && git push origin v0.1.1`. GitHub Actions crea la release con el zip y un `release.json` (flavors `classic` y `forever`), que es lo que lee WowUp. La versión del `.toc` se pone sola a partir de la etiqueta.

### A mano
Copia la carpeta `SolfaGuild` en `World of Warcraft\_classic_era_\Interface\AddOns\` (o la carpeta de AddOns del cliente de Forever).
Si el juego dice que el addon está "desactualizado", cambia el número de `## Interface:` de `SolfaGuild.toc` por el de tu cliente (`/dump (select(4, GetBuildInfo()))`).

Comandos: `/solfa` o `/sg` abre la ventana · `/sg sync` fuerza la sincronización · `/sg test` muestra una carta de prueba · `/sg campeo` muestra la ventana de campeo de prueba · `/sg minimap` muestra u oculta el botón del minimapa · `/sg recuperar` vuelve a pedir a la guild tus datos si los perdiste · `/sg debug`.

## Qué hace
| Función | Cómo funciona |
|---|---|
| **Main y alters** | Los SavedVariables son por cuenta, así que todos los personajes con los que entres quedan agrupados solos. En *Perfil* eliges tu main con el botón de la corona de cada personaje. Todos los rankings suman los datos de todos tus personajes y te muestran con el nombre de tu main en el color de su clase. Los demás solo ven a tu main, que engloba las estadísticas de todos tus personajes. |
| **Recuperar datos** | Si alguien borra su carpeta `WTF` (o entra en un PC nuevo), al entrar el addon pide a la guild la cuenta del personaje con el que juega y la recupera: main, alters, estadísticas, oro acumulado y hitos ya celebrados (no vuelven a salir las cartas ni se suma otra vez el oro que lleva encima). Mientras espera (30 s) no envía nada, para no tapar sus datos con una cuenta a cero. Si en ese rato no contesta nadie (no había nadie conectado), sigue jugando como cuenta nueva pero la recuperación queda pendiente 60 días: en cuanto le llegue su cuenta antigua (al entrar otro día con alguien conectado, o escribiendo `/sg recuperar`), se juntan las dos sin contar nada dos veces. Solo se recupera lo que llegó a sincronizarse, y solo si el personaje con el que entra ya era de esa cuenta. Nadie puede quedarse con la cuenta de otro: el juego garantiza quién envía cada mensaje. |
| **Ajustes del GM** | Solo el GM (rango 0) **y cualquier alter de su cuenta** ve la pestaña *GM*: activar o desactivar funciones, tiempos, quién puede crear eventos (por rango o mains a dedo) y la lista de **miembros sin el addon**. Los ajustes se envían a toda la guild. |
| **PvP** | Cuenta un asesinato cuando muere un jugador enemigo al que tú o tu mascota habéis dañado en los últimos 20 s (solo en mundo abierto). Rangos con su "carta" (la primera: *¡Has derramado sangre Alianza!*). La pestaña PvP (total o semanal; lo semanal se reinicia los miércoles, con el reinicio semanal del WoW) muestra el escalafón de asesinatos (rangos con un número de plazas, en `T.pvpLadder` de `Data/Texts.lua`), las zonas más sangrientas y los asesinatos coordinados: cuando varios Solfamidas con el addon dañan al mismo enemigo antes de que muera (no hace falta ir en grupo), ese equipo suma una muerte. Cuenta aunque vayan con alters y se muestra con el main de cada uno. El rango PvP del *Perfil* es el del escalafón. |
| **Oro** | Solo cuenta el oro acumulado (es la categoría *Góblin avaro* de *Cositas*; ya no tiene pestaña propia). La primera vez que entras con cada personaje se suma el oro que ya tenía, y a partir de ahí todo lo que gana cualquiera de tus personajes va al total de tu main (el oro que te envías por correo entre tus alters no cuenta). Los demás solo ven ese total, nunca el de cada personaje. Hitos de 10/100/1.000/5.000. |
| **Cositas** | Una lista de categorías tontas con un título (*Chill guy*, *P.E.T.A.*, *Bunny Hopper*...) en la que solo sale el mejor de la guild en cada una; pasando el ratón se ve de qué va y tu propio valor. Títulos y descripciones en `T.cositas` de `Data/Texts.lua`. Incluye el tiempo jugado (`/played`, que se pide en silencio al entrar). Sale de eventos y enganches a funciones del juego (saltar, `/roll`, emotes...); del registro de combate solo se mira lo tuyo (se descarta lo demás comparando el GUID, lo primero), para gastar lo mínimo en banda. Los contadores viajan con el latido de 5 min del perfil, sin envíos extra. |
| **Mazmorras (PvE)** | Una mazmorra cuenta como completada cuando muere su jefe final dentro de la instancia (NPC IDs en `Data/Dungeons.lua`). Hitos, ranking en la pestaña *PvE* y filtro de rango de mazmorras en los eventos. El registro de combate solo se escucha dentro de mazmorras y bandas. |
| **Ayudante de mazmorras** | Al llegar al nivel de las misiones de una mazmorra avisa con la lista de misiones (y waypoints con TomTom), y enseña quién de la guild está en rango y no la ha hecho, para susurrarle con un clic. |
| **Perfil** | Arriba, tu rango PvP y PvE. Abajo, dos listas: tus personajes (oro acumulado, asesinatos y mazmorras de cada uno; la corona elige el main) y las categorías de *Cositas* en las que eres el mejor. |
| **Susurros e invitaciones** | Pone una nota musical delante del nombre cuando te susurra alguien de la guild, y avisa cuando te invita a grupo un Solfamida. |
| **Aviso de zona** | Al entrar en una zona (como mucho una vez cada 30 min por zona, nunca en combate) te enseña qué Solfamidas hay en ella y puedes marcar a quién susurrar. Con clic derecho en el botón del minimapa lo lanzas a mano. |
| **SOS por campeo** | Si un jugador enemigo te mata 2 veces en 10 minutos en mundo abierto (configurable por el GM), te sale una ventana para pedir refuerzos. Si convocas a los Solfamidas, al resto con el addon le llega un aviso con tu zona; al convocar, si eres líder de tu grupo se pasa a banda, y si estás en un grupo sin ser líder sales de él para montar el tuyo (si vas solo, la banda se crea en cuanto entra el primero). Quien pulse *Acudir a la llamada* sale de su grupo, y en cuanto está fuera tú le invitas automáticamente y él acepta solo. Las invitaciones salen todas a la vez, y a quien no entre se le vuelve a invitar (al pasar a banda y cada 8 s, hasta 4 veces). |
| **Eventos** | Quien tenga permiso los crea (a quien no lo tiene ni le sale el botón) con filtros (rango de guild, nivel, clase, rango PvP o de mazmorras mínimo). Les llegan a los demás por el addon y les salta una carta X minutos antes y cuando empieza (fuera de combate). Si quieres, también se crea en el calendario del WoW: como evento de guild si es para todos, o con invitaciones a quienes cumplan el filtro (experimental). |

## Personalizar textos
Todos los mensajes, rangos y umbrales están en `Data/Texts.lua`. Marcadores: `%enemy%`, `%name%`, `%count%`, `%zone%`, `%dungeon%`.

## Pendiente / por revisar en Forever
- Poner en `## Interface:` de `SolfaGuild.toc` el número real del cliente de Forever (`/dump (select(4, GetBuildInfo()))`); `16001` es una suposición.
- WowUp: comprobar que reconoce la carpeta de Forever como cliente *Forever* y que instala/actualiza SolfaGuild desde la URL (usa el flavor `forever` del `release.json`; si no, revisar `.github/workflows/release.yml`).
- Semana: comprobar que en Forever existe `C_DateAndTime.GetSecondsUntilWeeklyReset` y que el reinicio semanal es el miércoles. Si la API no existe, el addon usa el miércoles a las 05:00 (hora del PC).
- PvP: comprobar que el registro de combate marca bien a los jugadores enemigos (hostiles) y a los aliados que no van en tu grupo; de eso dependen los asesinatos y los asesinatos coordinados.
- Probar la creación en el calendario del WoW (depende de la API del cliente y de los permisos de guild).
- SOS por campeo: comprobar en Forever que al morir salta `PLAYER_DEAD` y que el registro de combate marca como hostiles a los jugadores enemigos; que el addon puede salir del grupo, invitar y aceptar invitaciones solo (sin que el juego lo bloquee); y si Forever pasa el grupo a banda solo al invitar al 6º jugador o, como en Classic Era, hay que convertirlo (el addon lo convierte él mismo, así que funciona en los dos casos). Ver también si, yendo solo, el juego deja tener más de 4 invitaciones pendientes a la vez o rechaza las que sobran (si las rechaza, el addon las repite al pasar a banda).
- Cositas (`Modules/Cositas.lua`), comprobar en Forever:
  - **Estiloso**: Classic Era no tiene peluquería. Se cuenta con el evento `BARBER_SHOP_APPEARANCE_APPLIED` (solo se registra si existe). **Está oculta** (comentada en `T.cositas` de `Data/Texts.lua`) hasta comprobar en Forever que hay peluquería y que salta ese evento; entonces se descomenta. Si no hay peluquería, se borra.
  - **Meta chaser**: cuenta las llamadas a `ConfirmTalentWipe` (reiniciar talentos en el entrenador). Si Forever tiene doble especialización o reinicia talentos de otra forma, habrá que contarlo de otra manera.
  - **Broker** y **Manos callosas**: leen los mensajes del sistema a partir de las cadenas del juego `ERR_AUCTION_WON_S`, `LOOT_ITEM_CREATED_SELF` y `LOOT_ITEM_CREATED_SELF_MULTIPLE` (valen en cualquier idioma). Comprobar que siguen existiendo. Las subastas ganadas por puja estando desconectado no cuentan.
  - **P.E.T.A.**: se reconoce a los jabalíes por el nombre ("jabal" o "boar") con tu golpe final o el de tu mascota (`PARTY_KILL`).
  - **Fumeta**: hechizo *Recoger hierbas* (ID 2366, se compara por nombre).
  - Enganches a funciones del juego: `JumpOrAscendStart`, `RandomRoll`, `RollOnLoot`, `InspectUnit` y `DoEmote` (tokens `HUG`, `KISS`, `PET`...). Si alguno no existe en Forever, esa categoría se queda a 0 sin dar error.
  - **Sediento de sangre** usa `GetZonePVPInfo() == "hostile"`; **Paracaidista**, el daño de caída (`ENVIRONMENTAL_DAMAGE`) justo antes de `PLAYER_DEAD`.
- Mazmorras: revisar en Forever los niveles, misiones y NPC IDs de los jefes finales de `Data/Dungeons.lua` (solo hay misiones en las 4 primeras; faltan coordenadas para los waypoints) y que `IsInInstance()` devuelve `party`/`raid` dentro.

## Desarrollo
`lua5.1 tests/smoke.lua` ejecuta una prueba fuera del juego que simula la API de WoW.
