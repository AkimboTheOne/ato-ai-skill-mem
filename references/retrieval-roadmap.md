# Roadmap gobernado de retrieval y RAG

Este roadmap describe cómo evolucionar el retrieval de bajo nivel hacia una
capa RAG externa sin convertir la vault en estado oculto ni conceder autoridad
de escritura al runtime. `ato-ai-skill-mem` sigue siendo un módulo de memoria;
el futuro cerebro que razone sobre sus resultados no vive aquí.

## Ubicación técnica reservada

Los artefactos persistentes futuros vivirán bajo `vault/99_runtime/rag/`,
fuera de `20_domains/`. La extensión es opcional para conservar la
compatibilidad del formato `3`:

```text
99_runtime/rag/
├── manifest.yml
└── indexes/<index-id>/data/
```

El manifiesto será legible y versionable cuando exista un productor explícito.
Su esquema semántico se definirá en una propuesta posterior junto con la
operación de persistencia, invalidación y rollback. Los datos de índice serán
derivados, reconstruibles e ignorados por Git. Ninguna fase puede modificar la
memoria documental automáticamente. El layout base está definido en
[instance-contract.md](instance-contract.md).

## Estado actual

La fase inmediata usa `build` y `retrieve`:

- corpus Markdown completo con filtros explícitos;
- chunks estructurales por headings;
- provenance por archivo y líneas;
- retrieval léxico `OR` con ranking explicable;
- salida JSON transitoria;
- sin embeddings, vector database, proveedores LLM, red ni mutaciones.

El benchmark humano inicial vive en `tests/retrieval/eval_cases.json` y exige
`recall@5 >= 0.80` para considerar estable el retrieval léxico.

## Gates de evolución

### Gate 1: corpus

Debe existir un corpus determinista, reproducible y auditable. Cada chunk debe
conservar `path`, líneas, headings, texto, metadata e ID estable. Las rutas
incluidas y excluidas deben ser explícitas por invocación.

### Gate 2: retrieval léxico

Debe pasar los tests de determinismo, filtros, límites, errores, ausencia de
mutación y el dataset humano. No se añaden embeddings mientras el benchmark
no demuestre que la recuperación léxica es insuficiente para el caso real.

### Gate 3: retrieval semántico

Embeddings permanece `pending`. Su propuesta debe incluir necesidad medida,
modelo, coste, privacidad, dependencia, reproducibilidad, almacenamiento,
invalidación, rollback y comparación con el baseline léxico.

Una vector database no se autoriza por anticipación. Solo se considera si el
benchmark demuestra que el volumen o la latencia superan una alternativa local
simple y auditable.

### Gate 4: generación RAG externa

La generación será un componente separado sobre el retrieval demostrado. No se
añade al paquete `ato-ai-mem` ni al skill de memoria. Debe consumir resultados
con citas, conservar provenance, imponer un límite de contexto y permitir
ejecución local-first. Un proveedor externo requerirá autorización explícita y
sus efectos de red deberán ser visibles.

No se añade `ato-mem ask` durante la fase léxica. La generación no escribe en
la vault, no modifica relaciones y no crea memoria implícitamente.

### Gate 5: relaciones semánticas

La similitud puede producir propuestas revisables con evidencia y explicación.
Una persona decide si una propuesta se registra. La aplicación automática de
relaciones queda fuera del runtime por defecto.

## Evaluación

Cada caso humano contiene una consulta y uno o más `expected_paths`. La métrica
principal es `recall@5`: una consulta cuenta como acertada cuando al menos un
path esperado aparece entre los cinco primeros resultados. El umbral mínimo es
`0.80`; un resultado inferior aplaza embeddings y obliga a revisar primero el
corpus, el chunking, la consulta o el ranking.

La evaluación no convierte sus resultados en memoria persistente. Las
decisiones de evolución deben documentarse en los artefactos del repositorio y
solo una solicitud humana explícita puede crear o actualizar registros en
`vault/`.
