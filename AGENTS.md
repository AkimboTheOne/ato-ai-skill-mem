# AGENTS.md

Este repositorio usa `vault/` como almacenamiento de fuente para su memoria
documental local. No es un `mem/vault/` de consumidor ni debe instalarse
el skill sobre esta raíz. Sigue las reglas canónicas de [SKILL.md](SKILL.md);
este archivo no las duplica.

## Versionado del skill y del vault

Al cargar el skill, lee `VERSION`, `WORKSPACE_FORMAT` y, si existe,
`vault/.ato-ai-skill-mem-version.yml`. Comunica el diagnóstico de estado,
versión, formato, compatibilidad y modo antes de operar memoria. Aplica los
modos, su orden de prioridad y las condiciones de actualización definidos en
[SKILL.md](SKILL.md); no los reinterpretes ni los dupliques aquí.

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

La capacidad puede ser invocada desde un proyecto, un agente o una skill
compuesta. Sigue el contrato de contexto y propiedad del vault de
`SKILL.md`: las instrucciones del agente o de la skill anfitriona pueden
delegar en esta skill, pero no cambian quién posee los datos ni habilitan una
integración automática. El bootstrap implementa instalación de proyecto y un
adaptador de Codex; otros contextos requieren instrucciones explícitas del
anfitrión. No afirmes sincronización automática o fusión entre workspaces de
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
