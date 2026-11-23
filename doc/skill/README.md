# Skills del repositorio

## `local-mem`

`local-mem` recupera y administra memoria Markdown local, explícita y
trazable. Su raíz operativa es la carpeta que contiene `SKILL.md`, y consulta
exclusivamente su `wiki/` adyacente.

En este repositorio, el `wiki/` incluido es un layout base vacío. La
documentación del producto está en `doc/`; el historial que antes se
confundía con memoria activa está en [`doc/memory/history/`](../memory/history/).

## Componentes

- `SKILL.md`: activación, límites, autoridad y precedencia.
- `references/`: contratos y guías portables que forman parte de la skill.
- `scripts/`: diagnóstico y operaciones locales de wiki.
- `templates/`: plantillas de registros y estructura de dominios.
- `wiki/`: layout base sin datos iniciales.

La [guía de instalación y uso](installation.md) define cómo preparar la
carpeta `local-mem` y qué componentes incluye.

## `project-doc`

La skill local [`project-doc`](../../.agents/skills/project-doc/SKILL.md)
ayuda a mantener la documentación del repositorio bajo `doc/`. No forma parte
del paquete portable `local-mem` y no opera sobre la memoria `wiki/`.

Las dos skills tienen archivos `VERSION` independientes. La estructura de
datos de `wiki/` se versiona aparte mediante `WIKI_FORMAT`.
