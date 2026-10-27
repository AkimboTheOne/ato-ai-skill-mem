---
id: 2026-10-27--microsoft-copilot-adapter-mvp
type: project-context
status: active
created: 2026-10-27
updated: 2026-10-27
scope: project
author: human
sources:
  - SKILL.md
  - VERSION
  - VAULT_FORMAT
  - references/runtime-boundary.md
  - templates/integrations/microsoft-copilot/SKILL.md
  - templates/integrations/microsoft-copilot/connection-contract.md
  - scripts/package-microsoft-copilot.py
  - tests/test_microsoft_copilot_package.py
related:
  - "[Evolución 0.6.0](2026-10-27--project-evolution-0-6-0.md)"
supersedes: null
superseded_by: null
---

# Adaptador Microsoft 365 Copilot MVP

## Decisión

`ato-ai-skill-mem` mantiene un adaptador subordinado para Microsoft 365 Copilot.
El adaptador no tiene vida propia: la skill principal, `VERSION` y las reglas
de propiedad de la vault siguen siendo la fuente de verdad.

La integración es una capacidad pública retrocompatible y por ello se clasifica
como cambio `minor`: la versión de desarrollo pasa de `0.6.0` a `0.7.0`,
mientras `VAULT_FORMAT` permanece en `3`.

El primer destino es Microsoft 365 Copilot mediante Agent Builder y
declarative agents. La integración genera un ZIP cargable con un `SKILL.md`
adaptado y un contrato read-only. No es una integración de GitHub Copilot. El
standard harness de Copilot Studio requiere otro contrato y queda fuera de
este MVP. No se implementa todavía una API, MCP, connector, sincronización ni
escritura remota.

## Alcance operativo

El contrato mínimo expone conceptualmente `memory_check` y
`memory_retrieve`. Ambas operaciones deben conservar alcance autorizado,
provenance y citas. Si la capacidad externa no está configurada, el agente
debe informar que la memoria no está conectada y no inventar resultados.

El empaquetador se ejecuta desde el repositorio fuente y produce un artefacto
derivado versionado por la fuente. No incluye `vault/`, `.git/`, `AGENTS.md`,
los scripts de bootstrap ni el CLI local. No modifica la vault.

## Evolución y límites

Las instrucciones de Microsoft 365 Copilot se mantienen como una proyección
específica del contrato principal, no como una doctrina paralela. Cualquier
ampliación al standard harness de Copilot Studio, a API/MCP o a operaciones de
escritura requiere una revisión separada de alcance, estabilidad y gobernanza.
