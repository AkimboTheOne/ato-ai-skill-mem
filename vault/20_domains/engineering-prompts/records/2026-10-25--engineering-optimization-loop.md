---
id: 2026-10-25--engineering-optimization-loop
type: convention
status: active
created: 2026-10-25
updated: 2026-10-25
scope: project
author: human
sources:
  - SKILL.md
  - vault/AGENTS.md
  - ato-ai-skill-governance/SKILL.md
related: []
supersedes: null
superseded_by: null
---

# Ciclo reutilizable de optimización de ingeniería

## Activación

Cuando la persona diga “Ejecuta un ciclo de optimización”, o formule una
variante equivalente con un objetivo explícito, el agente ejecuta este ciclo
sobre la tarea actual. Si no hay un objetivo claro, solicita una aclaración
breve antes de analizar.

## Prompt operativo

Activa `ato-ai-skill-governance` en modo rector. Usa como entrada el objetivo
actual, la conversación relevante, los archivos inspeccionados y las
restricciones activas. Si el objetivo depende de decisiones, contratos,
convenciones o historial del producto, activa `ato-ai-source-mem`, ejecuta el
diagnóstico de la vault fuente y lee solo el contexto pertinente.

Ejecuta las fases en este orden:

1. **Question**: define el problema real, el resultado esperado, el
   responsable, las restricciones y los criterios de éxito. Formula preguntas
   solo si cambian la decisión.
2. **Eliminate**: elimina duplicados, pasos innecesarios, abstracciones sin
   uso, herramientas redundantes, automatización prematura y estado oculto.
3. **Simplify**: diseña el flujo mínimo explícito, determinista, auditable y
   reversible.
4. **Bound Scope**: define objetivo, superficies afectadas, límites,
   propiedad de datos, comportamientos excluidos y autorizaciones necesarias.
5. **Check Stability**: comprueba entradas, salidas, invariantes, fallos,
   rollback, pruebas y paridad entre runtimes. Clasifica el resultado como
   estable, parcialmente estable o inestable.

## Salida obligatoria

Entrega un informe con:

- contexto utilizado y fuentes consultadas;
- decisiones de cada fase;
- elementos eliminados;
- diseño simplificado;
- límites de alcance;
- riesgos y supuestos;
- evaluación de estabilidad;
- plan mínimo de implementación;
- pruebas y criterios de aceptación;
- autorización humana necesaria para cualquier cambio persistente.

El ciclo no escribe memoria ni modifica archivos por sí solo. No convierte una
recomendación en autorización. Solo después de demostrar estabilidad puede
proponer una fase posterior de aceleración o automatización; no la ejecuta
dentro de este ciclo.

## Evidencia y límites

Este prompt compone el orden de ingeniería solicitado con las primitivas de
`ato-ai-skill-governance`. No crea runtime, estado oculto, routing, RAG,
sincronización ni orquestación. La autoridad de escritura continúa en
`SKILL.md` y en la petición humana explícita.
