---
name: ato-ai-skill-mem
description: Administra memoria curada, local y versionable para un proyecto y sus agentes. Úsala cuando una tarea requiera consultar, registrar, actualizar, retirar o reemplazar decisiones, convenciones, aprendizajes o contexto de proyecto.
---

# ATO AI Skill Mem

## Propósito

Este skill mantiene una memoria explícita y legible por personas en
`workspace/`. Es una memoria compartida por el proyecto: cada registro indica
su autor, pero no existen subespacios separados por agente en el baseline.

El skill administra conocimiento curado. No captura automáticamente
conversaciones, no infiere aprendizajes para persistirlos y no funciona como un
segundo cerebro.

## Activación

Actívalo cuando una petición requiera historia o memoria del proyecto, por
ejemplo decisiones previas, convenciones, restricciones, lecciones aprendidas
o contexto activo. También se activa ante una instrucción explícita de guardar,
actualizar, retirar o reemplazar memoria.

No lo actives para tareas que no dependen de memoria persistente.

## Lectura selectiva

1. Lee `workspace/INDEX.md`.
2. Identifica los enlaces relevantes para la tarea actual.
3. Abre solo esos registros en `workspace/records/`.
4. Explica qué información de memoria modificó la decisión si resulta material.

No cargues todos los registros por defecto.

## Escritura explícita

Solo modifica `workspace/` cuando una persona pida expresamente registrar,
actualizar, retirar o reemplazar memoria. Una propuesta de cambio puede
presentarse sin escribir archivos.

Al crear un registro:

1. Usa una plantilla de `templates/records/`.
2. Nómbralo `YYYY-MM-DD--slug.md` dentro de `workspace/records/`.
3. Completa el front matter y la evidencia disponible.
4. Añade un enlace y un resumen de una línea a `workspace/INDEX.md`.

Al reemplazar un registro:

1. Crea el registro sucesor.
2. Cambia el anterior a `status: retired`.
3. Añade `superseded_by` en el anterior y `supersedes` en el nuevo.
4. Sustituye el enlace activo en `workspace/INDEX.md`; conserva la referencia
   histórica en la sección de retirados.

No borres un registro solo porque haya quedado obsoleto.

## Restricciones

- No guardes secretos, credenciales, tokens, datos personales sensibles ni
  transcripciones completas de conversaciones.
- No escribas de manera automática al cerrar una tarea o sesión.
- No introduzcas bases vectoriales, RAG, servicios externos, sincronización ni
  ejecución en segundo plano.
- No sobrescribas contenido existente durante una actualización de la
  instalación.

Consulta [references/instance-contract.md](references/instance-contract.md)
para el formato canónico, [references/agents-integration.md](references/agents-integration.md)
para la integración manual en proyectos consumidores y [templates/](templates/)
para las plantillas.
