---
name: local-mem
description: Recupera contexto documentado del proyecto desde la memoria Markdown de esta instalación. Úsalo cuando una tarea dependa de decisiones, convenciones, restricciones o lecciones previas; limita la consulta a `wiki/` junto a este `SKILL.md` y no busques ni mezcles memoria de otros proyectos, plugins o agentes.
---

# Módulo Local de Memoria

## Modelo

La carpeta que contiene el `SKILL.md` activado es la raíz de esta instancia.
Su única memoria es `wiki/` dentro de esa carpeta. Consulta y administra esa
ubicación solamente. No uses el directorio de trabajo, la ruta del proyecto,
el nombre de otra skill ni el contexto de otro plugin o agente para localizar
memoria; no busques ni aceptes una segunda raíz o una wiki configurada
externamente. Dos instalaciones son módulos separados aunque compartan el
mismo nombre técnico.

La memoria conserva conocimiento explícito, estable y trazable. No captura
conversaciones ni infiere aprendizajes para persistirlos. Usa español en la
documentación y la conversación; conserva en inglés los identificadores,
rutas, comandos y claves consumidos por herramientas.

## Consulta

Activa este módulo si el trabajo requiere recuperar decisiones previas,
convenciones del proyecto, restricciones acordadas, lecciones aprendidas o
contexto duradero. Es útil, por ejemplo, al continuar un diseño, revisar una
decisión previa o mantener compatibilidad con contratos existentes. Para una
tarea ordinaria que no dependa de ese contexto, no cargues la wiki.

Al activarla, ejecuta una vez `scripts/wiki.sh check` o, en PowerShell,
`scripts/wiki.ps1 check`. Comunica si la estructura es válida. Después lee
selectivamente `wiki/AGENTS.md`, `wiki/_indexes/INDEX.md`, mapas pertinentes,
metadata de dominios y solo el `AGENTS.md`, `INDEX.md` y registros del dominio
necesario. No cargues todos los registros por defecto.

Si el formato es incompatible, la estructura es ambigua o `wiki/` no existe,
detén la consulta de memoria; no busques ni inicialices otra ubicación.

## Autoridad y cambios

La lectura, el diagnóstico y las propuestas no autorizan escrituras. Crear,
actualizar, retirar, mover, archivar o reestructurar contenido requiere una
petición humana explícita. Conserva evidencia, procedencia e historial; no
sobrescribas ni borres contenido para resolver conflictos.

La precedencia es:

1. Este `SKILL.md`.
2. `wiki/AGENTS.md`.
3. `wiki/20_domains/<id>/AGENTS.md`.
4. La operación explícita de la persona.

Los dominios declaran `routing.rules: []`; no clasifiques por similitud,
confianza ni historial, y no apliques routing automáticamente. Si no hay un
dominio inequívoco, prepara una propuesta en `wiki/00_inbox/decisions-pending/`
solo cuando la persona haya pedido persistirla.

## Operaciones

Para toda operación, identifica su propósito, alcance, entradas y efectos;
consulta la referencia pertinente y usa solo el contexto necesario. Comprueba
el resultado frente a la solicitud y comunica lo relevante. Ante un error o
ambigüedad, detente, conserva la evidencia y revisa la causa antes de continuar;
no fuerces la operación ni supongas éxito.

Las consultas son de solo lectura: interpreta los resultados a la luz de las
fuentes originales y su estado. Para escribir, verifica autorización, destino,
contenido y efectos sobre registros y referencias. Usa el lock también en
operaciones manuales; si permanece, sigue su recuperación. Para mover o retirar,
revisa las referencias y aplica los cambios manualmente según la referencia.

- Para buscar, consulta [search.md](references/search.md).
- Para leer o cambiar contenido y orientar sus nombres, consulta [content-operations.md](references/content-operations.md).
- Para diagnóstico, layout, dominios o migración, consulta [wiki-operations.md](references/wiki-operations.md).
- Para preparación de publicaciones, consulta [release-readiness.md](references/release-readiness.md).

`VERSION` y `WIKI_FORMAT` son independientes.

## Límites

No implementes RAG operativo, embeddings, bases vectoriales, sincronización,
fusión de wikis, ejecución en segundo plano ni aprendizaje adaptativo.
