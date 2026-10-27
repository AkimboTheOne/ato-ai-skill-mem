---
id: 2026-10-26--project-evolution-0-5-1
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
  - references/instance-contract.md
  - vault/20_domains/project-context/records/2026-10-26--project-evolution-0-5-0.md
  - conversation-context
related:
  - "[Registro anterior](2026-10-26--project-evolution-0-5-0.md)"
supersedes: "[Registro anterior](2026-10-26--project-evolution-0-5-0.md)"
superseded_by: null
---

# Evolución del proyecto y decisiones de la versión 0.5.1

## Política editorial de versionado

La política del proyecto distingue la compatibilidad del skill de la
compatibilidad estructural de la vault:

- `X` (`major`) identifica cambios públicos no retrocompatibles.
- `Y` (`minor`) identifica nuevas capacidades públicas retrocompatibles.
- `Z` (`patch`) identifica correcciones, documentación, pruebas, CI, refactors
  internos y ajustes operativos sin nueva capacidad pública.

La misma interpretación se aplica durante `0.x` como convención editorial;
`1.0.0` representará el primer contrato estable declarado. `VAULT_FORMAT`
mantiene su propia política de migración y no se deriva automáticamente de
`VERSION`.

## Alcance de `0.5.1`

`0.5.1` es un release de parche: documenta la política SemVer y actualiza la
memoria de evolución sin añadir comandos, capacidades runtime ni cambios en
`VAULT_FORMAT=3`. El release conserva la separación entre la vault fuente y
las vaults consumidoras.

La rama de trabajo es `codex/0.5.1-versioning-policy`. El release debe
conservar el tag inmutable `v0.5.1` sobre el commit de release y actualizar
después únicamente el manifiesto de la vault fuente mediante
`--update-source-vault`.
