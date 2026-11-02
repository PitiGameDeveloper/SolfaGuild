# SolfaGuild

Addon de guild para **Los Solfamidas** (WoW Forever, Horda). Es para pasarlo bien: rankings, rangos de PvP propios, hitos de oro, eventos y algún detalle social.

> **IMPORTANTE: este addon es para WoW Forever (sale el 4 de noviembre de 2026).** Classic Era solo se usa para probarlo antes de que salga. Todo lo que se implemente tiene que funcionar en Forever; lo que pueda cambiar entre los dos clientes se apunta en *Pendiente / por revisar en Forever*. Más detalles en `CLAUDE.md`.

## Instalación
Copia la carpeta `SolfaGuild` en `World of Warcraft\_classic_era_\Interface\AddOns\` (o la carpeta de AddOns del cliente de Forever).
Si el juego dice que el addon está "desactualizado", cambia el número de `## Interface:` de `SolfaGuild.toc` por el de tu cliente (`/dump (select(4, GetBuildInfo()))`).

Comandos: `/solfa` o `/sg` abre la ventana · `/sg sync` fuerza la sincronización · `/sg test` muestra una carta de prueba · `/sg campeo` muestra la ventana de campeo de prueba · `/sg minimap` muestra u oculta el botón del minimapa · `/sg debug`.

## Qué hace
| Función | Cómo funciona |
|---|---|
| **Main y alters** | Los SavedVariables son por cuenta, así que todos los personajes con los que entres quedan agrupados solos. En *Perfil* eliges tu main con el botón de la corona de cada personaje. Todos los rankings suman los datos de todos tus personajes y te muestran con el nombre de tu main en el color de su clase. Los demás solo ven a tu main, que engloba las estadísticas de todos tus personajes. |
| **Ajustes del GM** | Solo el GM (rango 0) **y cualquier alter de su cuenta** ve la pestaña *GM*: activar o desactivar funciones, tiempos, quién puede crear eventos (por rango o mains a dedo) y la lista de **miembros sin el addon**. Los ajustes se envían a toda la guild. |
| **PvP** | Cuenta un asesinato cuando muere un jugador enemigo al que tú o tu mascota habéis dañado en los últimos 20 s (solo en mundo abierto). Rangos con su "carta" (la primera: *¡Has derramado sangre Alianza!*). La pestaña PvP (total o semanal; lo semanal se reinicia los miércoles, con el reinicio semanal del WoW) muestra el escalafón de asesinatos (rangos con un número de plazas, en `T.pvpLadder` de `Data/Texts.lua`), las zonas más sangrientas y los asesinatos coordinados: cuando varios Solfamidas con el addon dañan al mismo enemigo antes de que muera (no hace falta ir en grupo), ese equipo suma una muerte. Cuenta aunque vayan con alters y se muestra con el main de cada uno. El rango PvP del *Perfil* es el del escalafón. |
| **Oro** | Solo cuenta el oro acumulado. La primera vez que entras con cada personaje se suma el oro que ya tenía, y a partir de ahí todo lo que gana cualquiera de tus personajes va al total de tu main (el oro que te envías por correo entre tus alters no cuenta). Los demás solo ven ese total, nunca el de cada personaje. Hitos de 10/100/1.000/5.000. |
| **Tiempo** | Ranking de `/played` total (pide el dato en silencio al entrar). |
| **Susurros e invitaciones** | Pone una nota musical delante del nombre cuando te susurra alguien de la guild, y avisa cuando te invita a grupo un Solfamida. |
| **Aviso de zona** | Al entrar en una zona (como mucho una vez cada 30 min por zona, nunca en combate) te enseña qué Solfamidas hay en ella y puedes marcar a quién susurrar. Con clic derecho en el botón del minimapa lo lanzas a mano. |
| **SOS por campeo** | Si un jugador enemigo te mata 2 veces en 10 minutos en mundo abierto (configurable por el GM), te sale una ventana para pedir refuerzos. Si convocas a los Solfamidas, al resto con el addon le llega un aviso con tu zona; al convocar, si eres líder de tu grupo se pasa a banda, y si estás en un grupo sin ser líder sales de él para montar el tuyo (si vas solo, la banda se crea en cuanto entra el primero). Quien pulse *Acudir a la llamada* sale de su grupo, y en cuanto está fuera tú le invitas automáticamente y él acepta solo. Las invitaciones salen todas a la vez, y a quien no entre se le vuelve a invitar (al pasar a banda y cada 8 s, hasta 4 veces). |
| **Eventos** | Quien tenga permiso los crea con filtros (rango de guild, nivel, clase, rango PvP mínimo). Les llegan a los demás por el addon y les salta una carta X minutos antes y cuando empieza (fuera de combate). Si quieres, también se crea en el calendario del WoW: como evento de guild si es para todos, o con invitaciones a quienes cumplan el filtro (experimental). |

## Oculto de momento: PvE / mazmorras
Todo lo de mazmorras está desactivado pero se conserva comentado por si se quiere recuperar:
- **Mazmorras**: una mazmorra cuenta como completada cuando muere su jefe final dentro de la instancia (NPC IDs en `Data/Dungeons.lua`). Hitos y ranking.
- **Ayudante de mazmorras**: al llegar al nivel de las misiones de una mazmorra avisa con la lista de misiones (y waypoints con TomTom), y enseña quién de la guild está en rango y no la ha hecho, para susurrarle con un clic.

Para recuperarlo: quitar el `#` de `Data\Dungeons.lua`, `Modules\Dungeons.lua` y `Modules\DungeonHelper.lua` en `SolfaGuild.toc`, y descomentar en `UI/MainFrame.lua` las líneas marcadas con `PvE oculto` (pestaña *PvE*, bloque PvE del *Perfil*, filtro de rango de mazmorras de los eventos y casillas del GM). Los textos (`T.dungeonRanks`, `dhTitle`, `dhWhisper`), los ajustes por defecto y los datos guardados (`dungeons`, `dungeonsWeek`) se han dejado tal cual.
Al recuperarlo, revisar en Forever los niveles, misiones y NPC IDs de los jefes finales de `Data/Dungeons.lua` (solo hay misiones en las 4 primeras; faltan coordenadas para los waypoints).

## Personalizar textos
Todos los mensajes, rangos y umbrales están en `Data/Texts.lua`. Marcadores: `%enemy%`, `%name%`, `%count%`, `%zone%`, `%dungeon%`.

## Pendiente / por revisar en Forever
- Poner en `## Interface:` de `SolfaGuild.toc` el número real del cliente de Forever (`/dump (select(4, GetBuildInfo()))`); `16001` es una suposición.
- Semana: comprobar que en Forever existe `C_DateAndTime.GetSecondsUntilWeeklyReset` y que el reinicio semanal es el miércoles. Si la API no existe, el addon usa el miércoles a las 05:00 (hora del PC).
- PvP: comprobar que el registro de combate marca bien a los jugadores enemigos (hostiles) y a los aliados que no van en tu grupo; de eso dependen los asesinatos y los asesinatos coordinados.
- Probar la creación en el calendario del WoW (depende de la API del cliente y de los permisos de guild).
- SOS por campeo: comprobar en Forever que al morir salta `PLAYER_DEAD` y que el registro de combate marca como hostiles a los jugadores enemigos; que el addon puede salir del grupo, invitar y aceptar invitaciones solo (sin que el juego lo bloquee); y si Forever pasa el grupo a banda solo al invitar al 6º jugador o, como en Classic Era, hay que convertirlo (el addon lo convierte él mismo, así que funciona en los dos casos). Ver también si, yendo solo, el juego deja tener más de 4 invitaciones pendientes a la vez o rechaza las que sobran (si las rechaza, el addon las repite al pasar a banda).

## Desarrollo
`lua5.1 tests/smoke.lua` ejecuta una prueba fuera del juego que simula la API de WoW.
