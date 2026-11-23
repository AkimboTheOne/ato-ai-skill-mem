---
id: 2026-11-22--wiki-storage-location
type: project-context
status: active
created: 2026-11-22
updated: 2026-11-22
scope: project
author: human
sources:
  - SKILL.md
  - AGENTS.md
  - README.md
  - references/instance-contract.md
  - references/legacy-wiki-migration.md
  - scripts/wiki.sh
  - scripts/wiki.ps1
related:
  - "[Modo único de instalación del skill](2026-11-16--single-installation-mode.md)"
supersedes: "[Modo único de instalación del skill](2026-11-16--single-installation-mode.md)"
superseded_by: null
---

# Ubicación de la memoria en wiki

## Contexto

El nombre `vault/` podía sugerir un almacén de secretos o seguridad y no
comunicar que el contenido es documentación Markdown consultable por personas
y agentes.

## Decisión

La raíz única de memoria de cada instalación es `wiki/`, adyacente al
`SKILL.md` activado. La interfaz activa usa `WIKI_FORMAT`, `scripts/wiki.*` y
el diagnóstico `wiki.state`. El formato interno permanece en `3`.

## Evidencia

La solicitud humana prioriza una ubicación cuyo nombre describa mejor el uso
documental. El contrato mantiene aislamiento por instalación y no agrega
fallbacks ni migración automática desde `vault/`.

## Implicaciones operativas

Las instalaciones anteriores requieren respaldo y migración manual a `wiki/`.
El runtime no consulta ni traslada `vault/` o `mem/vault/`; ante una ruta
ausente, se detiene. Los registros históricos conservan sus rutas originales.
