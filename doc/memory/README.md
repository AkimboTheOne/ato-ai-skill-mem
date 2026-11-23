# Documentación de la memoria

## Separación

`doc/memory/` documenta la memoria y conserva el historial del proyecto.
`wiki/` es exclusivamente el layout base de la memoria local: contiene las
carpetas previstas, índices vacíos, plantillas y reglas generales, sin
registros, dominios de ejemplo ni decisiones del proyecto.

Cuando la skill se instala o copia para una instancia, `wiki/` queda junto a
su propio `SKILL.md`. La instancia puede recibir datos solo mediante una
petición explícita y según el contrato de [`local-mem`](../../SKILL.md).
El historial de este repositorio permanece en
[`history/`](history/), fuera de la memoria activa.

## Layout

`WIKI_FORMAT` declara el formato `3`. El baseline incluye `AGENTS.md`, las
carpetas operativas numeradas, `_indexes/`, `_maps/` y `_templates/`. Los
dominios y sus registros se crean únicamente cuando una instancia los
necesita; no se precargan con contexto de `ato-ai-skill-mem`.

El contrato y las operaciones están descritos en
[`instance-contract.md`](../../references/instance-contract.md) y
[`wiki-operations.md`](../../references/wiki-operations.md).
