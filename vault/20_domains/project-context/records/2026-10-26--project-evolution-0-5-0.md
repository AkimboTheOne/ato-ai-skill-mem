---
id: 2026-10-26--project-evolution-0-5-0
type: project-context
status: active
created: 2026-10-26
updated: 2026-10-26
scope: project
author: human
sources:
  - VERSION
  - VAULT_FORMAT
  - SKILL.md
  - README.md
  - references/vault-operations.md
  - scripts/bootstrap.sh
  - scripts/bootstrap.ps1
  - tests/fixtures/bootstrap-contract.tsv
  - tests/test-bootstrap.sh
  - tests/test-bootstrap.ps1
  - .github/workflows/test.yml
  - conversation-context
related:
  - "[Registro anterior](2026-10-26--project-evolution-0-4-0.md)"
supersedes: "[Registro anterior](2026-10-26--project-evolution-0-4-0.md)"
superseded_by: null
---

# Evolución del proyecto y decisiones de la versión 0.5.0

## Alcance y compatibilidad

La versión `0.5.0` mejora la calidad contractual y la trazabilidad operativa
sin cambiar `VAULT_FORMAT=3`. No introduce comandos runtime nuevos, estado
persistente oculto, sincronización automática, RAG, bases vectoriales,
auditoría autónoma ni ejecución en segundo plano.

La rama de trabajo es `codex/0.5.0-contract-parity`. La versión menor conserva
la propiedad separada de la vault fuente y de las vaults consumidoras.

## Contrato observable y paridad

La matriz `tests/fixtures/bootstrap-contract.tsv` define escenarios y
afirmaciones estables para `--contextualize`, `--status` y `--source-status`.
Bash y PowerShell validan los mismos estados, exit codes y decisiones visibles:
`needs-definition`, `structurally-ready`, `blocked`, y la separación entre
`source.state` y `vault.state`.

Las suites también cubren actualización de manifests, migraciones de
`workspace`, rechazo de usar la raíz fuente como consumidor, incompatibilidad
de `vault_kind`, integración Codex no sobrescribible y fixtures Git temporales
para validar precondiciones y actualizaciones positivas sin modificar el
checkout real.

## Documentación y validación

`README.md` y `references/vault-operations.md` exponen la autoridad,
precondiciones y efectos de cada modo. CI ejecuta las suites Bash y PowerShell
en sus matrices existentes y valida la vault fuente con `vault.sh check` o
`vault.ps1 check`.

La herramienta opcional `quick_validate.py` no se convierte en requisito de CI
en esta versión porque introduce una dependencia `PyYAML` no necesaria para el
contrato runtime.

## Release y límites

El release requiere `master`, checkout limpio y el tag inmutable `v0.5.0` en
el mismo commit de release. Después se actualiza únicamente el manifiesto de
la vault fuente con `--update-source-vault` y se confirma el commit documental
posterior. En ese checkout posterior, `source.state: not-release-aligned` es
esperado; la condición editorial final exige `vault.state: aligned` y
coherencia entre `skill_version`, `source_revision` y `source_tag`.

La creación futura de `release-check` o de una auditoría documental queda
aplazada hasta demostrar que la revisión manual actual es insuficiente.
