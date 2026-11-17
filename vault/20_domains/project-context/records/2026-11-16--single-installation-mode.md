---
id: 2026-11-16--single-installation-mode
type: project-context
status: active
created: 2026-11-16
updated: 2026-11-16
scope: project
author: codex
sources:
  - SKILL.md
  - AGENTS.md
  - README.md
  - references/instance-contract.md
  - references/vault-operations.md
  - references/release-readiness.md
  - scripts/vault.sh
  - scripts/vault.ps1
  - scripts/release-check.sh
  - scripts/release-check.ps1
  - .github/workflows/test.yml
  - conversation-context
related:
  - "[Evolución del proyecto y decisiones de la versión 0.6.0](2026-10-27--project-evolution-0-6-0.md)"
  - "[Adaptador Microsoft 365 Copilot, retirado](2026-10-27--microsoft-copilot-adapter-mvp.md)"
  - "[Preflight anterior, retirado](2026-10-27--release-preflight-and-governance.md)"
supersedes: "[Evolución 0.6.0](2026-10-27--project-evolution-0-6-0.md)"
superseded_by: null
---

# Modo único de instalación del skill

## Decisión

La carpeta que contiene `SKILL.md` es también la raíz operativa de la skill.
Su única memoria es `vault/` dentro de esa carpeta. La persona instala o copia
la skill completa, incluida la vault, y el agente no configura una ruta
externa ni elige un rol.

## Modos retirados

Se retiran del producto activo los roles `source` y `consumer`, las rutas
`vault/` frente a `mem/vault/`, el bootstrap de instalación, los adaptadores
Codex y Microsoft 365 Copilot, el manifiesto con `vault_kind` y el CLI Python
independiente `ato-mem`. Sus contratos y ejemplos quedan en
`references/history/` como documentación no operativa. El código de esas
interfaces deja de distribuirse.

## Compatibilidad y operación

El layout sigue en `VAULT_FORMAT=3`; no se cambia la estructura de los datos
Markdown ni se necesita migración de formato. `VERSION` continúa siendo una
dimensión separada. Los scripts estructurales resuelven `vault/` junto a la
skill y no aceptan argumentos de ámbito. `check` es el diagnóstico
estructural; la skill luego lee selectivamente la memoria.

Toda escritura continúa requiriendo una petición humana explícita. No se
añaden sincronización, RAG operativo ni estado persistente oculto.

## Evidencia

El cambio elimina el selector de rol y las instalaciones intermediarias, y
conserva en Markdown el histórico de los contratos retirados. La prueba de
aceptación confirma que un paquete aislado opera solo sobre su propia raíz y
rechaza rutas de ámbito antiguas.
