---
id: 2026-10-26--project-evolution-0-3-0
type: project-context
status: active
created: 2026-10-26
updated: 2026-10-26
scope: project
author: human
sources:
  - SKILL.md
  - AGENTS.md
  - references/instance-contract.md
  - references/vault-operations.md
  - conversation-context
related:
  - ../engineering-prompts/records/2026-10-25--engineering-optimization-loop.md
supersedes: null
superseded_by: null
---

# Evolución del proyecto y decisiones de la versión 0.3.0

## Resumen

`ato-ai-skill-mem` evolucionó de una memoria Markdown con `workspace/` a una
vault modular, contextual, portable y gobernada por personas. La versión
actual del skill es `0.3.0` y el contrato de datos es `VAULT_FORMAT=3`.
La vault fuente está alineada en datos, pero el checkout actual permanece en
desarrollo (`not-release-aligned`) hasta cumplir el flujo de release desde
`master` con `v0.3.0`.

## Decisiones de arquitectura

- `vault/` es el almacenamiento persistente de la fuente; un consumidor usa
  `mem/vault/`. No existe sincronización automática ni fusión entre vaults.
- `20_domains/<domain-id>/` es la única unidad portable. Cada dominio tiene
  `AGENTS.md`, `domain.yml`, `INDEX.md`, `records/` y `resources/`.
- La raíz contiene `AGENTS.md`, `_indexes/`, `_maps/`, `_templates/` y las
  áreas operativas de inbox, recursos, archivo, diarios y exportaciones.
- `domain.yml` exige `format`, `id`, `title`, `status`, `scope`, `areas` y
  `routing.rules: []`. No existe routing autónomo ni `auto_apply`.

## Migración y compatibilidad

- El cambio `workspace` → `vault` se adoptó como migración explícita.
- La versión `0.2.0` mantuvo `WORKSPACE_FORMAT=2`; la evolución modular llevó
  el proyecto a `0.3.0` y `VAULT_FORMAT=3`.
- La migración de formato `2` a `3` tiene preparación y finalización separadas.
  La preparación crea layout y propuestas; la finalización exige resolver
  todos los registros raíz, archiva el índice heredado y actualiza el
  manifiesto únicamente al final.
- Bash y PowerShell deben conservar las mismas precondiciones, diagnósticos,
  rollback, preservación byte a byte y garantías de no sobrescritura.

## Gobierno operativo

- La activación es contextual: las tareas ordinarias no cargan la vault.
- Al activar, el skill ejecuta `--status` o `--source-status`, identifica la
  composición mínima y lee selectivamente `AGENTS.md`, índices, metadata y el
  dominio pertinente.
- La supervisión de la vault usa `check` y puede revisar todos los
  `AGENTS.md` e `INDEX.md` para detectar incoherencias y oportunidades de
  reducir contexto. Es de solo lectura.
- La precedencia es `SKILL.md` → `vault/AGENTS.md` → `domain/AGENTS.md` →
  operación humana explícita. Una regla local no puede ampliar autoridad.
- Crear, actualizar, mover, archivar, exportar o cambiar estructura requiere
  una orden humana explícita. Las propuestas no son autorizaciones.
- Quedan fuera RAG, bases vectoriales, inferencia persistente, sincronización,
  automatización autónoma, estado oculto y orquestación recursiva.

## Adaptadores y contexto futuro

- `ato-ai-source-mem` es el adaptador autónomo de descubrimiento de `vault/`;
  no instala consumidores ni accede a `mem/vault/`.
- El adaptador Codex consumidor fija `mem/vault/` y delega reglas en el skill
  canónico.
- El dominio `engineering-prompts` conserva el prompt activado por “Ejecuta
  un ciclo de optimización”, que aplica `Question → Eliminate → Simplify →
  Bound Scope → Check Stability` usando el contexto actual.
- La memoria debe permanecer explícita, trazable, legible y portable para que
  un futuro consumidor pueda combinar una o más vaults sin recibir autoridad
  implícita para modificarlas.

## Pendientes

- Ejecutar el release desde `master`, con checkout limpio y tag `v0.3.0`, antes
  de actualizar el manifiesto de la vault fuente.
- Mantener paridad Bash/PowerShell y continuar las revisiones de consistencia
  cuando evolucione el contrato.
