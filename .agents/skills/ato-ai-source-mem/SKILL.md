---
name: ato-ai-source-mem
description: Consulta la memoria documental de la fuente de ato-ai-skill-mem cuando una tarea requiera decisiones, contratos, convenciones, historial o evolución persistente del producto.
---

# Memoria fuente de ato-ai-skill-mem

Este adaptador es el punto de entrada para la vault fuente del repositorio y
opera exclusivamente sobre `vault/`. Actívalo para tareas que dependan de
decisiones, contratos, convenciones o historial del producto; no para trabajo
ordinario. No accede a `mem/vault/`, no instala consumidores y no sincroniza
datos.

Al activarlo, ejecuta `scripts/bootstrap.sh --source-status` (o
`scripts/bootstrap.ps1 -SourceStatus`) como diagnóstico único. Si no está
disponible, consulta directamente `VERSION`, `VAULT_FORMAT` y el manifiesto.
Después sigue [SKILL.md](../../../SKILL.md) para composición, modos, lectura
selectiva, supervisión, precedencia, autoridad y detención. Toda consulta
fuente permanece dentro de `vault/`; nunca uses `--target .`.

Carga [source-workflows.md](references/source-workflows.md) solo para una
consulta de decisiones, revisión histórica, propuesta de conocimiento nuevo o
cambio solicitado que requiera un flujo específico de la fuente. Las
mutaciones, migraciones y releases usan exclusivamente los procedimientos
canónicos enlazados desde `SKILL.md`.
