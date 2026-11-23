---
id: 2026-11-22--evolucion-local-mem-y-validacion
type: project-context
status: active
created: 2026-11-22
updated: 2026-11-22
scope: project
author: codex
sources:
  - SKILL.md
  - AGENTS.md
  - README.md
  - requirements-dev.txt
  - .github/workflows/test.yml
  - wiki/20_domains/project-context/records/2026-11-22--wiki-storage-location.md
  - wiki/20_domains/engineering-prompts/records/2026-10-25--engineering-optimization-loop.md
  - conversation-context
related:
  - "[Ubicación de la memoria en wiki](2026-11-22--wiki-storage-location.md)"
supersedes: null
superseded_by: null
---

# Evolución de local-mem y su validación

## Contexto

El proyecto se reenfocó como Módulo Local de Memoria con el ID `local-mem`.
Cada instalación consulta la wiki adyacente a su propia skill. La selección
entre varias copias del mismo ID depende del anfitrión; el aislamiento de
cada instancia no garantiza cuál será seleccionada.

La memoria pasó de `vault/` a `wiki/` para expresar su propósito documental.
El registro relacionado conserva la decisión y sus efectos de migración.
El cambio incompatible se integró mediante el PR #9 y se publicó como
`v2.0.0` sobre el commit `05277c394d7388141a656dc602daadc14efc35eb`;
el formato de datos permaneció en `3`. Las instalaciones anteriores
requieren respaldo y migración manual.

## Evidencia

La revisión y estabilización incluyeron el rechazo de CR y LF en títulos de
 dominio y la protección frente a enlaces y puntos de reanálisis. El workflow
 del PR #9 terminó correctamente en Ubuntu, macOS y Windows, incluida la
 cobertura de junctions de Windows.

El PR #10 integró la validación reproducible: `requirements-dev.txt` fija
PyYAML como dependencia de desarrollo, `.venv` permite instalarla por clon y
CI ejecuta el validador de metadatos. La dependencia no es requisito de uso de
la memoria. La guía de desarrollo y el flujo de validación están en `README.md`
y `AGENTS.md`; el commit integrado fue `cb0425488249d178fbd53c4b9f1f4a039e78f517`.

## Implicaciones operativas

Para el propio repositorio se creó `.agents/skills/local-mem` como enlace a la
raíz y se ajustó `AGENTS.md` para remitir a la skill de esta instancia. Codex
la descubrió en la sesión posterior. Al redactar este registro, esos cambios
seguían locales y sin commit.

El ciclo de optimización de la wiki dejó de indicar el identificador técnico
anterior: remite a los artefactos de la skill para la activación y el
diagnóstico de memoria. Esta actualización también estaba local y sin commit
al registrar este contexto. Las escrituras en la wiki siguen requiriendo una
petición humana explícita.
