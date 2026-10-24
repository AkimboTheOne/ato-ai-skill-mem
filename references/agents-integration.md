# Integración del agente

El bootstrap no modifica instrucciones de agentes. Copia este bloque de forma
manual al AGENTS.md del proyecto consumidor cuando quieras activar la memoria
del proyecto:

~~~md
## Memoria del proyecto

Cuando una tarea dependa de decisiones, convenciones, lecciones o contexto
duradero del proyecto, lee `mem/SKILL.md`, `mem/VERSION`,
`mem/WORKSPACE_FORMAT` y, si existe,
`mem/workspace/.ato-ai-skill-mem-version.yml`.

Al cargar el skill, comunica un diagnóstico breve de fuente, versiones,
formatos, compatibilidad de datos y modo recomendado antes de operar memoria.
Usa estos modos: operación compatible para formatos compatibles; desarrollo
sin promoción si la fuente no es `release-aligned`; revisión de fuente o
workspace más nuevo si la versión o revisión difiere; planificación de
migración si el formato es incompatible; e instalación pendiente si no existe
workspace. En planificación de migración no interpretes registros como
compatibles ni escribas datos; explica impacto y espera confirmación humana.
En operación compatible, lee `mem/workspace/INDEX.md` y abre solo los
registros relevantes para la tarea.

Mantén separadas la versión del skill y el formato de datos del workspace. Los
workspaces de formato `1`, incluidos los heredados sin manifiesto de versión,
pueden operarse con las versiones `0.x` y `1.x` de este skill sin reescribir
registros. Recomienda actualizar el manifiesto solo si la fuente es
`release-aligned`, la versión del skill es más reciente y una persona lo pide
explícitamente. Nunca rebajes un manifiesto ni lo actualices desde una fuente
de desarrollo. Si el formato es incompatible, explica impacto y migración
propuesta, y espera confirmación humana explícita; no migres ni sobrescribas
datos.

No escribas, retires ni reemplaces memoria del proyecto salvo petición humana
explícita. No guardes secretos, credenciales, datos sensibles ni
transcripciones completas de conversaciones en el workspace.
~~~

## Migración desde una integración administrada

Si una instancia anterior contiene los marcadores `ato-ai-skill-mem:start` y
`ato-ai-skill-mem:end`, reemplaza manualmente todo ese bloque por el anterior.
No ejecutes de nuevo `bootstrap` para migrar: deliberadamente no modifica
`AGENTS.md`.
