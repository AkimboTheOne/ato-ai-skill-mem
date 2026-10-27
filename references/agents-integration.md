# Integración del agente

El bootstrap no modifica instrucciones de agentes. Copia este bloque de forma
manual al AGENTS.md del proyecto consumidor cuando quieras activar la memoria
del proyecto:

Este documento describe consumidores. El adaptador fuente
`.agents/skills/ato-ai-source-mem/` pertenece exclusivamente al repositorio
canónico: diagnostica y consulta `vault/`, no se instala en consumidores ni
reemplaza el adaptador local de Codex.

Si el proyecto usa Codex, también puede crear el adaptador de descubrimiento
local con `--integrate-codex`. Es independiente de este bloque y no modifica
`AGENTS.md`.

Cuando una tarea del consumidor toque Microsoft 365 Copilot, Agent Builder o
Copilot Studio, consulta el `capability-contract.md` distribuido con el
adaptador. Trátalo como una proyección subordinada del skill principal: no
inventes capacidades, no mezcles fuentes y conserva `source`, `locator`,
`revision`, `citation` y `scope`. Esta guía no convierte el consumidor en
propietario de la vault fuente ni implica sincronización automática.

~~~md
## Memoria del proyecto

Cuando una tarea dependa de decisiones, convenciones, lecciones o contexto
duradero del proyecto, sigue `mem/SKILL.md`. La vault de este proyecto es
exclusivamente `mem/vault/`; para tareas ordinarias no cargues memoria. El
skill canónico define diagnóstico, modos, lectura selectiva y autoridad. No
uses la vault fuente ni sincronices contenido entre vaults.
~~~

## Migración desde una integración administrada

Si una instancia anterior contiene los marcadores `ato-ai-skill-mem:start` y
`ato-ai-skill-mem:end`, reemplaza manualmente todo ese bloque por el anterior.
No ejecutes de nuevo `bootstrap` para migrar: deliberadamente no modifica
`AGENTS.md`.
