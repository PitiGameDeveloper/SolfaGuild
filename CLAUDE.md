# SolfaGuild — LEER ANTES DE TOCAR NADA

## Lo más importante: el addon es para FOREVER, no para Classic Era

- **El cliente objetivo es WoW Forever** (sale el 4 de noviembre de 2026). Classic Era solo se usa
  **para poder probar antes de que salga Forever**.
- **TODO lo que se implemente tiene que funcionar en Forever.** Si una función depende de algo que
  puede cambiar entre Classic Era y Forever (API, eventos, reglas de grupo/banda, niveles, IDs de NPC,
  mazmorras, calendario…), hay que:
  1. escribir el código para que funcione en los dos (comprobar si existe la API nueva, por ejemplo
     `C_PartyInfo.X`, y si no usar la antigua; nada que solo exista en Classic Era sin alternativa);
  2. apuntarlo en la sección **"Pendiente / por revisar en Forever"** del `README.md` para comprobarlo
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

## Distribución (WowUp desde GitHub)
- La guild instala el addon con **WowUp → Instalar desde URL** → `https://github.com/PitiGameDeveloper/SolfaGuild`.
- **El repo se queda público a propósito**: no importa que alguien vea o descargue el código, y no se puede
  obligar a la guild a crearse cuenta de GitHub (un repo privado exigiría cuenta + token en WowUp a cada uno).
  No proponer hacerlo privado.
- Para publicar una versión: `git tag vX.Y.Z` y `git push origin vX.Y.Z`. El workflow
  `.github/workflows/release.yml` crea la release con `SolfaGuild-vX.Y.Z.zip` (sin `.github`, `.gitignore`
  ni `CLAUDE.md`) y un `release.json` (formato del packager de BigWigs) con los flavors `classic` y `forever`,
  que es lo que lee WowUp para elegir el zip. La `## Version:` del `.toc` se pone sola a partir de la etiqueta.
- Pendiente en Forever: comprobar que WowUp reconoce el cliente como *Forever* (apuntado en el `README.md`).
- El GM también lo instala con WowUp: **no crear enlaces/junctions** de la carpeta del proyecto en
  `Interface\AddOns` (el que había en `_classic_era_` se quitó). Los cambios llegan al juego publicando versión.
