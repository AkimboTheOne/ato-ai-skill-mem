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
  - references/capability-contract.md
  - references/integration-alignment.md
  - AGENTS.md
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

La línea de trabajo permanece en `0.7.0`: la homologación portable de
capacidades todavía no se ha promovido a un release separado. `VAULT_FORMAT`
permanece en `3`.

El primer destino es Microsoft 365 Copilot mediante Agent Builder y
declarative agents. La integración genera un ZIP cargable con un `SKILL.md`
adaptado, un contrato read-only de conexión y un contrato portable de
capacidades. No es una integración de GitHub Copilot. La proyección documental
es portable entre Agent Builder y Copilot Studio, pero no promete las mismas
fuentes, permisos, citas o modelos. No se implementa todavía una API, MCP,
connector, sincronización ni escritura remota.

## Alcance operativo

El contrato mínimo conserva `memory_check` y `memory_retrieve` por
compatibilidad y los homologa a `inspect` y `search`. El contrato portable
también define `fetch` y `transform`: el primero exige un locator y evidencia
exacta; el segundo procesa temporalmente contenido ya recuperado, sin runtime
local nuevo ni persistencia. Todas las operaciones deben conservar alcance
autorizado, provenance y citas. Si la capacidad externa no está configurada,
el agente debe informar que la memoria no está conectada y no inventar
resultados.

El empaquetador se ejecuta desde el repositorio fuente y produce un artefacto
derivado versionado por la fuente. No incluye `vault/`, `.git/`, `AGENTS.md`,
los scripts de bootstrap ni el CLI local. No modifica la vault.

## Evolución y límites

Las instrucciones de Microsoft 365 Copilot se mantienen como una proyección
específica del contrato principal, no como una doctrina paralela. SharePoint,
OneDrive y conectores de Microsoft 365 se consideran perfiles `grounding`;
MCP, REST, CLI, Confluence y Azure DevOps Wiki son perfiles `tool` futuros.
Cualquier ampliación concreta requiere una revisión separada de alcance,
estabilidad y gobernanza.

La revisión posterior identificó y corrigió dos riesgos: `memory_check` ya no
hardcodea una versión antigua, porque el empaquetador materializa `VERSION`,
y el contrato portable define entradas y salidas mínimas para `inspect`,
`search`, `fetch` y `transform`, conservando citas, alcance y procedencia.

La alineación permanente queda documentada en
`references/integration-alignment.md` y referenciada desde el `AGENTS.md` y
el `SKILL.md` fuente. La guía de consumidores añade la misma advertencia sin
modificar automáticamente sus instrucciones.
