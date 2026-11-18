---
name: local-mem
description: Recupera contexto documentado del proyecto desde la memoria Markdown de esta instalación. Úsalo cuando una tarea dependa de decisiones, convenciones, restricciones o lecciones previas; limita la consulta a `vault/` junto a este `SKILL.md` y no busques ni mezcles memoria de otros proyectos, plugins o agentes.
---

# Módulo Local de Memoria

## Modelo

La carpeta que contiene el `SKILL.md` activado es la raíz de esta instancia.
Su única memoria es `vault/` dentro de esa carpeta. Consulta y administra esa
ubicación solamente. No uses el directorio de trabajo, la ruta del proyecto,
el nombre de otra skill ni el contexto de otro plugin o agente para localizar
memoria; no busques ni aceptes una segunda raíz o una vault configurada
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
tarea ordinaria que no dependa de ese contexto, no cargues la vault.

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
