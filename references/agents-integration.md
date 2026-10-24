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
Aplica la evaluación de carga y el orden de modos de `mem/SKILL.md`; ese
documento es la fuente canónica para compatibilidad, actualizaciones y
migraciones. Solo en operación compatible, lee `mem/workspace/INDEX.md` y
abre los registros relevantes para la tarea. Los demás modos deben producir
una recomendación visible sin escribir datos.

No escribas, retires ni reemplaces memoria del proyecto salvo petición humana
explícita. No guardes secretos, credenciales, datos sensibles ni
transcripciones completas de conversaciones en el workspace.
~~~

## Migración desde una integración administrada

Si una instancia anterior contiene los marcadores `ato-ai-skill-mem:start` y
`ato-ai-skill-mem:end`, reemplaza manualmente todo ese bloque por el anterior.
No ejecutes de nuevo `bootstrap` para migrar: deliberadamente no modifica
`AGENTS.md`.
