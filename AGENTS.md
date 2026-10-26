# AGENTS.md

Este repositorio usa `vault/` como almacenamiento de fuente para su memoria
documental local. No es un `mem/vault/` de consumidor ni debe instalarse
el skill sobre esta raíz. Sigue las reglas canónicas de [SKILL.md](SKILL.md);
este archivo no las duplica.

## Versionado del skill y del vault

Al activar memoria, ejecuta `scripts/bootstrap.* --source-status` como
diagnóstico único y comunica el resultado antes de leer. La lectura directa de
archivos de versión y manifiesto es alternativa solo si el comando no está
disponible. Aplica los modos y autoridad definidos en [SKILL.md](SKILL.md).

El manifiesto de este vault tiene `vault_kind: source`. Para
consultarlo usa `scripts/bootstrap.* --source-status` (o `-SourceStatus`).
Solo actualiza su referencia de release mediante la operación explícita de
fuente, desde `master`, con checkout limpio y el tag `v<VERSION>` en `HEAD`.
La actualización no crea tags ni commits: una persona revisa y confirma el
commit documental posterior. Los consumidores usan `mem/vault/` y los
comandos con `--target`; nunca comparten registros con este vault.

Este repositorio fuente expone un adaptador estático de descubrimiento en
`.agents/skills/ato-ai-source-mem/`. Este adaptador usa solamente
`vault/`, no instala una instancia ni crea enlaces simbólicos. La
integración `--integrate-codex` sigue perteneciendo exclusivamente a proyectos
consumidores y crea un punto de descubrimiento separado para
`mem/vault/`.

Para ejecutar un ciclo reutilizable de optimización, usa el dominio
`vault/20_domains/engineering-prompts/`: lee su `AGENTS.md`, el `INDEX.md` y
el registro activo `2026-10-25--engineering-optimization-loop.md`. La frase
“Ejecuta un ciclo de optimización” activa `Question → Eliminate → Simplify →
Bound Scope → Check Stability` sobre el objetivo y contexto actuales. El
ciclo produce análisis y un plan; no autoriza cambios persistentes.

La capacidad puede ser invocada desde un proyecto, un agente o una skill
compuesta. Sigue el contrato de contexto y propiedad del vault de
`SKILL.md`: las instrucciones del agente o de la skill anfitriona pueden
delegar en esta skill, pero no cambian quién posee los datos ni habilitan una
integración automática. El bootstrap implementa instalación de proyecto y un
adaptador de Codex; otros contextos requieren instrucciones explícitas del
anfitrión. No afirmes sincronización automática o fusión entre vaults de
proyectos distintos: Git puede versionar la memoria de cada consumidor,
mientras que compartir conocimiento entre proyectos requiere promoción
deliberada.

## Idioma

Usa español para el razonamiento comunicado, las conversaciones, la
documentación, los ejemplos y los diagnósticos dirigidos a personas. Conserva
en inglés los identificadores de programación, nombres de archivos, comandos,
claves de contratos, valores consumidos por herramientas y términos técnicos
establecidos. Un implementador puede cambiar el idioma de un proyecto
consumidor cuando lo documente expresamente en sus instrucciones locales.
