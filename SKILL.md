---
name: ato-ai-skill-mem
description: Consulta y administra memoria Markdown curada del skill cuando una tarea requiera decisiones, convenciones, lecciones o contexto persistente.
---

# Memoria local del skill

## Modelo

La carpeta que contiene este `SKILL.md` es la raíz operativa. Su única vault es
`vault/`; consulta y administra esa ubicación. No busques ni aceptes una
segunda raíz, un proyecto destino o una vault configurada externamente.

La memoria conserva conocimiento explícito, estable y trazable. No captura
conversaciones ni infiere aprendizajes para persistirlos. Usa español en la
documentación y la conversación; conserva en inglés los identificadores,
rutas, comandos y claves consumidos por herramientas.

## Consulta

Activa la memoria solo si la tarea depende de decisiones, convenciones,
restricciones, lecciones aprendidas o contexto duradero. Para tareas ordinarias
no cargues la vault.

Al activarla, ejecuta una vez `scripts/vault.sh check` o, en PowerShell,
`scripts/vault.ps1 check`. Comunica si la estructura es válida. Después lee
selectivamente `vault/AGENTS.md`, `vault/_indexes/INDEX.md`, mapas pertinentes,
metadata de dominios y solo el `AGENTS.md`, `INDEX.md` y registros del dominio
necesario. No cargues todos los registros por defecto.

Si el formato es incompatible, la estructura es ambigua o `vault/` no existe,
detén la consulta de memoria; no busques ni inicialices otra ubicación.

## Autoridad y cambios

La lectura, el diagnóstico y las propuestas no autorizan escrituras. Crear,
actualizar, retirar, mover, archivar o reestructurar contenido requiere una
petición humana explícita. Conserva evidencia, procedencia e historial; no
sobrescribas ni borres contenido para resolver conflictos.

La precedencia es:

1. Este `SKILL.md`.
2. `vault/AGENTS.md`.
3. `vault/20_domains/<id>/AGENTS.md`.
4. La operación explícita de la persona.

Los dominios declaran `routing.rules: []`; no clasifiques por similitud,
confianza ni historial, y no apliques routing automáticamente. Si no hay un
dominio inequívoco, prepara una propuesta en `vault/00_inbox/decisions-pending/`
solo cuando la persona haya pedido persistirla.

Los scripts `scripts/vault.sh` y `scripts/vault.ps1` operan sobre la única
`vault/` junto a esta skill. Consulta [vault-operations.md](references/vault-operations.md)
para comandos estructurales y migraciones. La versión del skill (`VERSION`) y
el formato de datos (`VAULT_FORMAT`) son independientes; las reglas de
publicación están en [release-readiness.md](references/release-readiness.md).

## Límites

No implementes RAG operativo, embeddings, bases vectoriales, sincronización,
fusión de vaults, ejecución en segundo plano ni aprendizaje adaptativo.
