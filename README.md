# SolfaGuild

Addon de guild para **Los Solfamidas** (WoW Classic / Forever, Horda). Es para pasarlo bien: rankings, rangos de PvP propios, hitos de oro y mazmorras, eventos y algún detalle social.

## Instalación
Copia la carpeta `SolfaGuild` en `World of Warcraft\_classic_era_\Interface\AddOns\` (o la carpeta de AddOns del cliente de Forever).
Si el juego dice que el addon está "desactualizado", cambia el número de `## Interface:` de `SolfaGuild.toc` por el de tu cliente (`/dump (select(4, GetBuildInfo()))`).

Comandos: `/solfa` o `/sg` abre la ventana · `/sg sync` fuerza la sincronización · `/sg test` muestra una carta de prueba · `/sg minimap` muestra u oculta el botón del minimapa · `/sg debug`.

## Qué hace
| Función | Cómo funciona |
|---|---|
| **Main y alters** | Los SavedVariables son por cuenta, así que todos los personajes con los que entres quedan agrupados solos. En *Perfil* eliges tu main (cuando quieras) y puedes añadir alters a mano. Todos los rankings suman los datos de todos tus personajes y te muestran con el nombre de tu main en el color de su clase. Pasa el ratón por encima de una fila para ver el desglose por personaje. |
| **Ajustes del GM** | Solo el GM (rango 0) **y cualquier alter de su cuenta** ve la pestaña *GM*: activar o desactivar funciones, tiempos, quién puede crear eventos (por rango o mains a dedo) y la lista de **miembros sin el addon**. Los ajustes se envían a toda la guild. |
| **PvP** | Cuenta un asesinato cuando muere un jugador enemigo al que tú o tu mascota habéis dañado en los últimos 20 s (solo en mundo abierto). Rangos con su "carta" (la primera: *¡Has derramado sangre Alianza!*). Rankings: total, esta semana, zonas más sangrientas y parejas más despiadadas. |
| **Oro** | Oro actual (suma de todos tus personajes) y oro recolectado a lo largo del tiempo (el oro que te envías por correo entre tus alters no cuenta). Hitos de 10/100/1.000 tanto de recolectado como de oro en la bolsa. |
| **Mazmorras** | Una mazmorra cuenta como completada cuando muere su jefe final dentro de la instancia (NPC IDs en `Data/Dungeons.lua`). Hay hitos y ranking. |
| **Tiempo** | Ranking de `/played` total (pide el dato en silencio al entrar). |
| **Ayudante de mazmorras** | Al llegar al nivel de las misiones de una mazmorra te avisa con la lista de misiones (y waypoints si tienes TomTom y hay coordenadas), y te enseña quién de la guild está en rango y no la ha hecho, para susurrarle con un clic. Se desactiva a partir del nivel que configure el GM. |
| **Susurros e invitaciones** | Pone una nota musical delante del nombre cuando te susurra alguien de la guild, y avisa cuando te invita a grupo un Solfamida. |
| **Aviso de zona** | Al entrar en una zona (como mucho una vez cada 30 min por zona, nunca en combate) te enseña qué Solfamidas hay en ella y puedes marcar a quién susurrar. Con clic derecho en el botón del minimapa lo lanzas a mano. |
| **Eventos** | Quien tenga permiso los crea con filtros (rango de guild, nivel, clase, rango PvP mínimo, rango de mazmorras mínimo). Les llegan a los demás por el addon y les salta una carta X minutos antes y cuando empieza (fuera de combate). Si quieres, también se crea en el calendario del WoW: como evento de guild si es para todos, o con invitaciones a quienes cumplan el filtro (experimental). |

## Personalizar textos
Todos los mensajes, rangos y umbrales están en `Data/Texts.lua`. Marcadores: `%enemy%`, `%name%`, `%count%`, `%zone%`, `%dungeon%`.

## Pendiente / por revisar en Forever
- Comprobar en el cliente de Forever los niveles y las misiones de cada mazmorra en `Data/Dungeons.lua` (de momento solo hay misiones en las 4 primeras; faltan coordenadas para los waypoints).
- Comprobar los NPC IDs de los jefes finales.
- Probar la creación en el calendario del WoW (depende de la API del cliente y de los permisos de guild).

## Desarrollo
`lua5.1 tests/smoke.lua` ejecuta una prueba fuera del juego que simula la API de WoW.
