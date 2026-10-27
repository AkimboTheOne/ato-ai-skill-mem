---
id: 2026-10-27--release-preflight-and-governance
type: project-context
status: active
created: 2026-10-27
updated: 2026-10-27
scope: project
author: human
sources:
  - VERSION
  - VAULT_FORMAT
  - AGENTS.md
  - SKILL.md
  - README.md
  - references/release-readiness.md
  - references/instance-contract.md
  - scripts/bootstrap.sh
  - scripts/bootstrap.ps1
  - scripts/release-check.sh
  - scripts/release-check.ps1
  - tests/test-bootstrap.sh
  - tests/test-bootstrap.ps1
  - review-agent
  - conversation-context
related:
  - "[Evolución del proyecto 0.6.0](2026-10-27--project-evolution-0-6-0.md)"
  - "[Ciclo de optimización](../../engineering-prompts/records/2026-10-25--engineering-optimization-loop.md)"
supersedes: null
superseded_by: null
---

# Preflight de release y gobernanza del agente

## Decisión

El repositorio incorpora un preflight read-only para el gate de release en
`scripts/release-check.sh` y `scripts/release-check.ps1`. Las dos interfaces
deben conservar paridad y producen salida `text` o `json`.

El preflight comprueba `VERSION`, `VAULT_FORMAT`, la rama `master`, el estado
limpio del checkout, la existencia de `v<VERSION>`, la coincidencia entre
`HEAD` y el tag, la alineación local con `origin/master` y
`vault.sh check --source`. El modo `--post-release`/`-PostRelease` comprueba
también el manifiesto fuente y permite como única excepción el cambio
controlado de `vault/.ato-ai-skill-mem-version.yml`, tanto staged como
unstaged, antes del commit documental posterior.

El preflight no crea tags, commits, pushes ni modifica la vault. La decisión
de SemVer, el merge, la publicación y la operación explícita
`--update-source-vault` permanecen separados y gobernados por una persona.

## Gobernanza

Cuando `ato-ai-skill-governance` esté disponible para el proyecto o su agente,
debe utilizarse en planificación, diseño, validación y simplificación. La
secuencia mínima es `Question → Eliminate → Simplify → Bound Scope → Check
Stability`; no se añade automatización de publicación antes de demostrar
estabilidad y auditabilidad.

## Evidencia y corrección aplicada

La revisión read-only detectó que el primer preflight rechazaba
incorrectamente el modo posterior al release cuando el manifiesto ya estaba
staged. La implementación se corrigió para comparar contra `HEAD` y los
fixtures Bash y PowerShell cubren ahora ambos estados.

La validación ejecutada después de la corrección obtuvo 25 tests unitarios,
tests Bash y PowerShell de bootstrap/vault, `sh -n` y `git diff --check` sin
hallazgos. El benchmark de retrieval mantiene `12/12` y `recall@5 = 1.0`.

## Implicaciones operativas

- El release publicado continúa siendo `0.7.0`; `VAULT_FORMAT` continúa en
  `3`.
- El cambio del preflight es una capacidad pública retrocompatible y puede
  clasificarse como `minor` en el gate; `0.8.0` es una versión candidata, no
  una versión todavía publicada.
- El siguiente release debe ejecutarse desde `master`, con `VERSION` decidido
  sobre el diff final, tag inmutable `v<VERSION>`, actualización documental
  posterior y verificación final del manifiesto.
- No se introduce RAG, embeddings, bases vectoriales, sincronización,
  ejecución en segundo plano ni estado persistente oculto.
