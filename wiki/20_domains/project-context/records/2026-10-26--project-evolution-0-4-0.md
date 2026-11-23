---
id: 2026-10-26--project-evolution-0-4-0
type: project-context
status: retired
created: 2026-10-26
updated: 2026-10-26
scope: project
author: human
sources:
  - VERSION
  - VAULT_FORMAT
  - SKILL.md
  - scripts/bootstrap.sh
  - scripts/bootstrap.ps1
  - tests/test-bootstrap.sh
  - tests/test-bootstrap.ps1
  - conversation-context
related:
  - "[Registro anterior](2026-10-26--project-evolution-0-3-0.md)"
  - ../engineering-prompts/records/2026-10-25--engineering-optimization-loop.md
supersedes: "[Registro anterior](2026-10-26--project-evolution-0-3-0.md)"
superseded_by: "[Evolución del proyecto y decisiones de la versión 0.5.0](2026-10-26--project-evolution-0-5-0.md)"
---

# Evolución del proyecto y decisiones de la versión 0.4.0

## Corrección histórica

La evolución modular descrita por el registro anterior correspondía a la
versión `0.3.0`. El estado correcto inmediatamente anterior a esta evolución
es `VERSION=0.3.1` con `VAULT_FORMAT=3`. El registro anterior se conserva como
historia y queda retirado; este registro es la referencia activa del contexto
del proyecto.

## Inicialización como máquina de estados

El bootstrap mantiene compatibilidad cuando se ejecuta sin una operación
explícita, pero expone transiciones gobernables. `--init` permite solo
`absent → scaffolded`; `--status` inspecciona sin mutar y `--contextualize`
presenta el inventario y el wizard guiado. Las migraciones y actualizaciones
de versión siguen siendo operaciones separadas.

El diagnóstico distingue `new` y `existing`, y expone un estado transitorio de
contextualización: `needs-definition`, `needs-review`, `structurally-ready` o
`blocked`. No se persiste un marcador de vault contextualizada.

## Wizard y gestión de datos

La contextualización ocurre en cuatro iteraciones: definir propósito,
audiencia y límites; leer reglas, índices, mapas y metadata pertinente; acordar
tipos de registros, evidencia, ciclo de vida, inbox y trazabilidad; y validar
con `check` antes de solicitar una escritura explícita.

El bootstrap realiza únicamente inventario estructural. No clasifica por
similitud, no infiere memoria, no activa routing y no crea planes persistentes.
Crear, actualizar, mover, archivar o cambiar estructura continúa requiriendo
autorización humana acotada.

## Release

La versión del skill pasa a `0.4.0` sin cambiar `VAULT_FORMAT=3`. El release
requiere fusionar en `master`, crear manualmente `v0.4.0` sobre el mismo `HEAD`,
verificar `release-aligned` y ejecutar `--update-source-vault` para actualizar
solo el manifiesto de la vault fuente. El bootstrap no crea tags ni commits.

## Criterio editorial de publicación y alineación

`source.state: release-aligned` es una precondición del momento de publicar y
actualizar el manifiesto, no una condición permanente del checkout posterior.
El tag público debe permanecer inmutable sobre el commit de merge del release.
Después de confirmar el commit documental del manifiesto, `master` queda una
revisión después del tag y `source.state: not-release-aligned` es esperado.

La alineación final se declara cuando el tag remoto conserva el commit de
release, `master` local coincide con `origin/master`, y `vault.state: aligned`
confirma que `skill_version`, `source_revision` y `source_tag` apuntan al
release publicado. No se fuerza ni se mueve el tag para incorporar el commit
documental posterior.
