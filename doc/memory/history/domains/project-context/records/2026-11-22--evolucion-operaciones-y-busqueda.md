---
id: 2026-11-22--evolucion-operaciones-y-busqueda
type: project-context
status: active
created: 2026-11-22
updated: 2026-11-22
scope: project
author: codex
sources:
  - conversation-context
  - SKILL.md
  - references/content-operations.md
  - references/search.md
  - scripts/content.py
  - scripts/search.py
  - TO-DO.md
related:
  - "[Evolución de local-mem y su validación](2026-11-22--evolucion-local-mem-y-validacion.md)"
supersedes: null
superseded_by: null
---

# Evolución de las operaciones y la búsqueda de local-mem

## Contexto

La evolución de `local-mem` amplió los flujos documentales desde los registros de dominio hacia los demás contextos de la memoria local: pendientes, áreas, recursos, diarios, exportaciones, mapas y archivo. La instalación utiliza únicamente la `wiki/` adyacente a la skill. El operador, que puede ser una persona o un agente delegado, selecciona el contexto y utiliza la plantilla apropiada; no hay clasificación automática. Las escrituras requieren una petición humana explícita.

La skill conserva las reglas comunes y dirige a referencias específicas. Las plantillas incorporan metadatos y los nombres nuevos siguen convenciones explícitas; los nombres heredados permanecen consultables. Los scripts Bash y PowerShell atienden la instancia y el diagnóstico estructural; los asistentes Python apoyan las operaciones de contenido y búsqueda.

## Evidencia

La conversación de trabajo acordó y maduró estos flujos; la interfaz vigente y sus límites están documentados en [operaciones de contenido](../../../../../../references/content-operations.md) y [búsqueda local](../../../../../../references/search.md). La evolución de instalación y validación se documenta en el [registro relacionado](2026-11-22--evolucion-local-mem-y-validacion.md).

- `content.py` consulta, prepara plantillas, crea y actualiza documentos. Para registros de dominio conserva metadatos protegidos y añade al índice una entrada basada en el identificador, evitando que el Markdown de un título rompa el enlace. La creación y actualización registran su operación en el log.
- Un lock visible coordina las escrituras de las interfaces participantes. Las operaciones preparan sus cambios, detectan conflictos e intentan revertirlos si falla la publicación; los cambios entre archivos no son atómicos. La recuperación de una interrupción o reversión incompleta requiere revisión.
- Mover y retirar requieren revisión y ejecución manuales bajo el lock. Los planes de la CLI inventarían archivos y huellas, pero no identifican todas las referencias. El retiro conserva el documento en el archivo y exige atender índices, referencias e historial.
- `search.py` ofrece búsqueda literal, regex y léxica por palabras, con filtros de dominio, índices y encabezados. La búsqueda léxica no entiende intención ni sinónimos; embeddings y búsqueda semántica local quedaron aplazados para evaluación basada en evidencia.
- La revisión integral se orientó a hallazgos demostrables y a distinguir bloqueos reales de pendientes. Las correcciones recientes abarcaron trazabilidad, protección de la estructura y el estado de registros, y enlaces de índice; se verificaron mediante pruebas en copias temporales.

## Implicaciones operativas

El agente debe interpretar los resultados de búsqueda junto con sus fuentes y revisar el alcance de cada cambio autorizado. Los planes de movimiento o retiro no sustituyen la inspección de referencias; ante ambigüedad se detiene la operación. Las instrucciones de gobierno del proyecto piden una revisión integral por iteración y verificaciones enfocadas después de corregir, evitando ciclos automáticos indefinidos.

El trabajo pendiente y cualquier evaluación de capacidades adicionales se mantienen en [TO-DO.md](../../../../../../TO-DO.md). Este artículo resume decisiones y resultados de la conversación; no es una transcripción ni sustituye los contratos activos.
