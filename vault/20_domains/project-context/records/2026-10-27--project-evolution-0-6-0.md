---
id: 2026-10-27--project-evolution-0-6-0
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
  - references/runtime-boundary.md
  - references/python-cli.md
  - references/vault-operations.md
  - scripts/bootstrap.sh
  - scripts/bootstrap.ps1
  - scripts/vault.sh
  - scripts/vault.ps1
  - src/ato_ai_mem/scope.py
  - tests/test_cli.py
  - tests/test-bootstrap.sh
  - tests/test-bootstrap.ps1
  - tests/test-install.sh
  - conversation-context
related:
  - "[Registro anterior](2026-10-26--project-evolution-0-5-1.md)"
  - ../engineering-prompts/records/2026-10-25--engineering-optimization-loop.md
supersedes: "[Registro anterior](2026-10-26--project-evolution-0-5-1.md)"
superseded_by: null
---

# Evolución del proyecto y decisiones de la versión 0.6.0

## Decisión de gobierno

El proyecto mantiene `ato-mem` como un MVP técnico de bajo nivel: lectura
documental, retrieval léxico determinista, provenance y diagnósticos. No es
un cerebro, no genera respuestas y no contiene RAG operativo, embeddings,
bases vectoriales ni estado persistente oculto.

El ciclo de validación y simplificación identificó como riesgo principal que
una herramienta de soporte pudiera aceptar una ruta arbitraria y operar fuera
de la vault de referencia. La decisión es imponer una frontera técnica por
rol, derivada y auditable:

- `source` recibe `SOURCE_ROOT` y solo resuelve `SOURCE_ROOT/vault/`.
- `consumer` recibe `PROJECT_PATH` y solo resuelve `PROJECT_PATH/mem/vault/`.
- `--vault` y `-Vault` no son interfaces válidas.
- Las raíces autorizadas, `mem/`, `mem/vault/` y los marcadores de rol no
  pueden ser symlinks.
- Un consumidor no puede ser la fuente ni estar dentro de la fuente.

La resolución común se concentra en `src/ato_ai_mem/scope.py` para el CLI;
los scripts Bash y PowerShell aplican el mismo contrato. `references/runtime-boundary.md` es la fuente normativa del límite y `AGENTS.md` solo lo
referencia.

## Alcance y compatibilidad

La evolución conserva `VAULT_FORMAT=3`, la propiedad separada de las vaults y
la reserva técnica opcional `99_runtime/rag/`. `build` y `retrieve` siguen
reconstruyendo el corpus en memoria; ningún comando Python crea índices,
escribe la vault o accede a red. Los scripts solo mutan la vault derivada del
rol explícito y no crean datos RAG automáticamente.

No se modifica `vault/` por operaciones ordinarias del CLI, no se actualizan
tags ni manifests de release, y la memoria fuente no se comparte con
consumidores.

## Simplificación aplicada

Se eliminan las rutas de vault elegidas libremente y las variantes duplicadas
de resolución. El contrato mínimo queda reducido a dos roles, dos entradas
(`--source`/`--target`) y una ruta operativa derivada por rol. La prohibición
de symlinks y la detección de proyectos anidados hacen explícito el límite sin
introducir sandboxing, procesos de fondo ni nuevas dependencias de runtime.

## Evidencia de estabilidad

La implementación fue validada con 21 pruebas `unittest`, pruebas Bash y
PowerShell, smoke de instalación con `python -m pip install .`, ejecución de
ambos entrypoints y comprobación de no mutación. También pasó `git diff
--check`. El runtime no requiere dependencias externas; el acceso a PyPI fue
necesario únicamente para el backend de build del smoke test.

## Pendientes gobernados

- Mantener el contrato de frontera en cualquier nueva interfaz de soporte.
- Proponer una revisión separada antes de introducir persistencia RAG,
  embeddings o bases vectoriales.
- Ejecutar el protocolo de release desde `master` y actualizar el manifiesto
  de la vault fuente solo mediante la operación canónica posterior al tag.
