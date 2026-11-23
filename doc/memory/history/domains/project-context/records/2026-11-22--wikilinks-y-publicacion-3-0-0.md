---
id: 2026-11-22--wikilinks-y-publicacion-3-0-0
type: project-context
status: active
created: 2026-11-22
updated: 2026-11-22
scope: project
author: codex
sources:
  - SKILL.md
  - VERSION
  - references/content-operations.md
  - references/release-readiness.md
  - scripts/content.py
  - tests/test_content.py
  - https://github.com/AkimboTheOne/ato-ai-skill-mem/pull/13
related:
  - "[Evolución de las operaciones y la búsqueda](2026-11-22--evolucion-operaciones-y-busqueda.md)"
supersedes: null
superseded_by: null
---

# Curaduría de Wikilinks y publicación 3.0.0

## Contexto

La integración local con Obsidian usa `wiki/` como vault existente y mantiene a `local-mem` como autoridad de ámbito y reglas. Se añadió una herramienta opcional para curar Wikilinks a enlaces Markdown portables; la lectura y edición directa de archivos permanece disponible y no hay sincronización ni routing automático.

## Evidencia

`content.py plan-links` produce un plan JSON de solo lectura con inventario, diff, conversiones, enlaces sin resolver y sintaxis no admitida. `apply-links --plan` vuelve a validar el plan, opera bajo el lock compartido y registra cambios en el action log. La conversión se limita a destinos explícitos o nombres de nota únicos y encabezados únicos; conserva alias y no modifica `.obsidian/`, el action log ni enlaces dentro de código y comentarios. Para front matter procesa únicamente cadenas y listas citadas de `sources`, `related`, `supersedes` y `superseded_by`. Los destinos ambiguos, embeds, referencias a bloques y formatos no compatibles se informan y quedan intactos.

La revisión detectó que delimitadores de comentario dentro del código inline podían cambiar el análisis. El parser se ajustó para recorrer delimitadores de código y comentarios en orden, con pruebas de sus interacciones. La suite completa pasó: 56 pruebas Python, validación de metadatos, pruebas Bash y PowerShell, checks estructurales de wiki y `git diff --check`.

El diff acumulado desde `v2.0.0` se clasificó como incompatible y `VERSION` se actualizó a `3.0.0`; `WIKI_FORMAT` permanece en `3`. La PR #13 se integró en `main` mediante squash en `1fe915e6488a565b1ffeb1d79a200546aa6d1e5a`. El tag anotado `v3.0.0` apunta al mismo commit. El preflight final devolvió `ready: true`, sin bloqueos.

## Implicaciones operativas

Antes de aplicar una conversión, revisa el diff completo y mantén el plan fuera de `wiki/`. No edites la wiki mientras se aplica el plan; el lock coordina solo procesos cooperantes y no elimina la carrera con editores externos. `v3.0.0` es la versión integrada y publicada; el formato de datos no requiere migración por esta capacidad.
