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

## Otras notas
- Todo el texto del juego y del código está en español.
- Los textos editables están en `Data/Texts.lua`; los ajustes del GM (con sus valores por defecto) en
  `Modules/Settings.lua` y su pantalla en `UI/MainFrame.lua` (pestaña GM).
- Cada módulo nuevo se añade al `SolfaGuild.toc`.
