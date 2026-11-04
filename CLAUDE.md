# SolfaGuild — LEER ANTES DE TOCAR NADA

## Lo más importante: el addon es para FOREVER, no para Classic Era

- **El cliente objetivo es WoW Forever** (sale el 4 de noviembre de 2026). Classic Era solo se usa
  **para poder probar antes de que salga Forever**.
- **TODO lo que se implemente tiene que funcionar en Forever.** Si una función depende de algo que
  puede cambiar entre Classic Era y Forever (API, eventos, reglas de grupo/banda, niveles, IDs de NPC,
  mazmorras, calendario…), hay que:
  1. escribir el código para que funcione en los dos (comprobar si existe la API nueva, por ejemplo
     `C_PartyInfo.X`, y si no usar la antigua; nada que solo exista en Classic Era sin alternativa);
  2. apuntarlo en **`PROBAR.md`**, la lista de cosas que probar, para comprobarlo
     en cuanto salga Forever.
- No hay que decir "esto es para Classic Era" ni dar por hechas las reglas de Classic Era. Si no se sabe
  cómo funciona algo en Forever, se dice y se apunta como pendiente.

## Mantener este archivo al día
- Siempre que cambie algo sustancial en la manera de trabajar o en el proyecto (cómo se publica, decisiones
  tomadas, estructura, reglas nuevas…) que haga falta saber en otras conversaciones, **actualiza este
  `CLAUDE.md` automáticamente**, sin esperar a que lo pidan, y menciónalo en la respuesta.

## Otras notas
- Todo el texto del juego y del código está en español.
- Los textos editables están en `Data/Texts.lua`; los ajustes del GM (con sus valores por defecto) en
  `Modules/Settings.lua` y su pantalla en `UI/MainFrame.lua` (pestaña GM).
- Cada módulo nuevo se añade al `SolfaGuild.toc`.
- **En Forever el registro de combate está prohibido** (`COMBAT_LOG_EVENT_UNFILTERED` da un aviso de "bloqueado"
  al jugador) y hay valores ocultos (`issecretvalue`, usar `SG:Open`): solo se registra si `SG.HasCombatLog`. Hay
  otras vías: `UNIT_DIED`, `PARTY_KILL`, muertes honorables y `C_DeathRecap` (ver `Modules/PvP.lua` y
  `Modules/CampSOS.lua`), hechizos propios (`UNIT_SPELLCAST_*`) y `C_DamageMeter` para curación y daño, como Details
  (`Modules/Cositas.lua`; sus valores están ocultos en combate, se leen al salir).
- **PvP en Forever: decisión del GM.** Solo cuentan las muertes honorables. Un asesinato coordinado es que varios
  Solfamidas avisen de una muerte honorable con el mismo identificador del muerto (`UNIT_DIED`/`PARTY_KILL`); si falta,
  misma zona a la vez y mismo grupo u objetivo. Eso nunca suma asesinatos. Un enemigo que no da honor no debe contar
  (si un 60 ayuda a un 20, al 60 no le cuenta).
- **Mazmorras completadas: decisión del GM.** Los Solfamidas que la hacen en el mismo grupo suman una sola completación;
  en grupos separados, una cada uno (`DungeonTracker:Runs`). Esto vale para "mazmorras más completadas" y "grupos"; el
  escalafón personal sigue dando una a cada jugador.
- **En Forever los personajes tienen apellido.** La clave de un personaje es lo que dan `SG:Short`, `SG:MyName` y
  `SG:UnitFull` ("Nombre Apellido"). Nunca usar `UnitName(unit)` a secas ni `strsplit("-", nombre)`. Para susurrar o
  invitar, `SG:Target(nombre)` (`Comm:Send` ya lo hace). Para saber si alguien va en tu grupo, `SG:InMyGroup(nombre)`.
- **Para saber cómo es Forever**, mirar el cliente instalado: `World of Warcraft\_forever_\Interface\AddOns`
  (Attune, MuddyBoots, NeedRoll y AtlasLootClassic ya resuelven muchas de estas cosas). Es mejor fuente que las guías.
- **Rendimiento mínimo, sobre todo en banda.** Usar eventos raros o `hooksecurefunc`. Si una estadística no se
  puede contar barato, no se hace. Los contadores que
  cambian a menudo no llaman a `SG:MarkDirty()`: el perfil se comprueba cada minuto y solo sale si ha cambiado (sin
  contar el tiempo jugado), o cada 5 min aunque no haya cambiado.
- **Cola de mensajes (`Comm.lua`).** Si el juego limita un mensaje (`SendAddonMessage` da `AddonMessageThrottle` y similares)
  se reintenta; los `LFS_*` van por delante de los perfiles. Un mensaje nuevo del LFS debe empezar por `LFS_`.
- **Cositas que se pueden macrear** (decisión del GM): lo que se hace sin coste lleva tope (`LIMITS` en `Modules/Cositas.lua`).
  Con objetivo (Sobón, Stalker, Solfamicida): otro jugador obligatorio y uno cada 2 min, sea a quien sea. Sin objetivo
  (Ludópata, Cartero): solo espera. Una categoría nueva que se pueda macrear debe pasar por `addLimited`. **Estos topes son secretos, para que nadie los aproveche:** no mencionarlos en las descripciones ni en ningún texto del juego.
- **Personajes borrados o vueltos a crear.** El juego no da la lista de personajes de la cuenta. Uno que ya no sale en la
  lista completa de la guild deja de contar, pero sus datos no se tocan (`SG:MyGuildChars`). Si entra otro con el mismo
  nombre y otro `UnitGUID` en el mismo reino, empieza de cero (`Core.lua`); con otro reino es un traslado y los conserva.
- Datos nuevos de personaje: si se guardan en `SG:MyChar()` y viajan en el perfil, añadirlos también a
  `restoreFrom` de `Modules/Players.lua` (recupera la cuenta desde la guild si se borra el `WTF`). Mientras
  `SG.restoring` es cierto no se envía el perfil ni salen hitos.
- Para leer mensajes del sistema, construir el patrón a partir de la cadena del juego (`ERR_...`,
  `LOOT_...` de GlobalStrings), nunca escribir el texto a mano: así vale en cualquier idioma.

## Pruebas
- `python tests/run.py` simula el addon con varios clientes (necesita `tests/requirements.txt`). Pasarlo antes de publicar
  y añadir ahí los casos nuevos. Una API nueva del juego hay que añadirla también a `tests/mock.lua`. Solo prueba la
  lógica: lo que dependa de cómo se comporta Forever se sigue apuntando en `PROBAR.md`.

## Distribución (WowUp desde GitHub)
- La guild instala el addon con **WowUp → Instalar desde URL** → `https://github.com/PitiGameDeveloper/SolfaGuild`.
- **El repo se queda público a propósito**: no importa que alguien vea o descargue el código, y no se puede
  obligar a la guild a crearse cuenta de GitHub (un repo privado exigiría cuenta + token en WowUp a cada uno).
  No proponer hacerlo privado.
- Para publicar una versión: `git tag vX.Y.Z` y `git push origin vX.Y.Z`. El workflow
  `.github/workflows/release.yml` crea la release con `SolfaGuild-vX.Y.Z.zip` (sin `.github`, `.gitignore`,
  `CLAUDE.md`, `PROBAR.md` ni `tests`) y un `release.json` (formato del packager de BigWigs) con los flavors `classic` y `forever`,
  que es lo que lee WowUp para elegir el zip. La `## Version:` del `.toc` se pone sola a partir de la etiqueta.
- Pendiente en Forever: comprobar que WowUp reconoce el cliente como *Forever* (apuntado en `PROBAR.md`).
- El GM también lo instala con WowUp: **no crear enlaces/junctions** de la carpeta del proyecto en
  `Interface\AddOns` (el que había en `_classic_era_` se quitó). Los cambios llegan al juego publicando versión.
