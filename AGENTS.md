# AGENTS.md

Este repositorio usa `workspace/` para su memoria local. Sigue las reglas
canónicas de [SKILL.md](SKILL.md); este archivo no las duplica.

## Versionado del skill y del workspace

Antes de recomendar una actualización o cambiar memoria, lee `VERSION`,
`WORKSPACE_FORMAT` y, si existe, `workspace/.ato-ai-skill-mem-version.yml`.
Distingue siempre la versión del skill del formato de datos del workspace.
Al cargar el skill, comunica un diagnóstico de estado, versión, formato,
compatibilidad y modo recomendado antes de operar memoria. `SKILL.md` define
los modos canónicos y sus límites.

- El formato `1` es compatible durante todas las versiones `0.x` y `1.x`.
  Un skill nuevo debe poder leer y operar esos workspaces sin reescribir sus
  registros.
- Un manifiesto ausente o sin `workspace_format` es un workspace heredado de
  formato `1`: informa la recomendación, pero no escribas metadata por ello.
- Recomienda actualizar la marca solo cuando la fuente sea `release-aligned`,
  la versión sea más reciente y una persona lo pida explícitamente. Nunca
  rebajes una marca de versión ni la actualices desde una fuente de desarrollo.
- Si el formato no es compatible, explica impacto y pasos propuestos, y pide
  confirmación humana. No ejecutes migraciones ni sobrescribas datos.

## Idioma

Usa español para el razonamiento comunicado, las conversaciones, la
documentación, los ejemplos y los diagnósticos dirigidos a personas. Conserva
en inglés los identificadores de programación, nombres de archivos, comandos,
claves de contratos, valores consumidos por herramientas y términos técnicos
establecidos. Un implementador puede cambiar el idioma de un proyecto
consumidor cuando lo documente expresamente en sus instrucciones locales.
