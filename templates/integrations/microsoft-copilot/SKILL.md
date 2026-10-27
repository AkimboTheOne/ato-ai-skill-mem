---
name: ato-ai-skill-mem-microsoft-365-copilot
description: Consulta memoria Markdown curada y versionable desde Microsoft 365 Copilot cuando una tarea requiera decisiones, convenciones, historial o contexto persistente; no inventa memoria ni escribe sin autorización explícita.
---

# Memoria de proyecto para Microsoft 365 Copilot

Esta skill está dirigida a Microsoft 365 Copilot y sus declarative agents. No
es una skill de GitHub Copilot ni define el standard harness de Copilot Studio.

Usa esta skill solo cuando la solicitud dependa de decisiones, convenciones,
historial o contexto estable del proyecto. No la uses como memoria de
conversación ni como un segundo cerebro.

## Orden de trabajo

1. Si existe una capacidad configurada `memory_check`, úsala antes de consultar
   memoria. Comunica el estado, la versión y el alcance que devuelve.
2. Lee únicamente el contexto pertinente a la solicitud.
3. Si existe una capacidad `memory_retrieve`, úsala con una consulta concreta y
   conserva las citas devueltas.
4. Responde distinguiendo hechos recuperados, inferencias y recomendaciones.
5. Si la capacidad de memoria no está conectada, dilo claramente y no simules
   resultados ni cites documentos que no hayas recibido.

## Límites

- La memoria pertenece al proyecto que la publica y no debe mezclarse con
  memorias de otros proyectos.
- No captures conversaciones como memoria persistente.
- No infieras aprendizajes para guardarlos automáticamente.
- No actives RAG operativo, embeddings, bases vectoriales, búsqueda semántica,
  sincronización automática ni fusión de vaults.
- No aceptes rutas arbitrarias para seleccionar una vault.
- No escribas, muevas, archives, exportes ni cambies registros sin una
  solicitud humana explícita, acotada y verificable.
- Si una operación de escritura no está disponible, presenta una propuesta y
  detente.

## Evidencia y respuesta

Usa las citas y el `provenance` de la capacidad configurada. Si hay conflicto,
formato incompatible, alcance ambiguo o falta de evidencia, informa el problema
en vez de elegir otra memoria por similitud.

Mantén las respuestas en español, salvo que la persona pida otro idioma.
Conserva en inglés los nombres de herramientas, campos, rutas y valores de
contrato.
