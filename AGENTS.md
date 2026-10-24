# AGENTS.md

Este repositorio usa `workspace/` como workspace de fuente para su memoria
documental local. No es un `mem/workspace/` de consumidor ni debe instalarse
el skill sobre esta raíz. Sigue las reglas canónicas de [SKILL.md](SKILL.md);
este archivo no las duplica.

## Versionado del skill y del workspace

Al cargar el skill, lee `VERSION`, `WORKSPACE_FORMAT` y, si existe,
`workspace/.ato-ai-skill-mem-version.yml`. Comunica el diagnóstico de estado,
versión, formato, compatibilidad y modo antes de operar memoria. Aplica los
modos, su orden de prioridad y las condiciones de actualización definidos en
[SKILL.md](SKILL.md); no los reinterpretes ni los dupliques aquí.

El manifiesto de este workspace tiene `workspace_kind: source`. Para
consultarlo usa `scripts/bootstrap.* --source-status` (o `-SourceStatus`).
Solo actualiza su referencia de release mediante la operación explícita de
fuente, desde `master`, con checkout limpio y el tag `v<VERSION>` en `HEAD`.
La actualización no crea tags ni commits: una persona revisa y confirma el
commit documental posterior. Los consumidores usan `mem/workspace/` y los
comandos con `--target`; nunca comparten registros con este workspace.

Este repositorio fuente expone un adaptador estático de descubrimiento en
`.agents/skills/ato-ai-source-mem/`. Este adaptador usa solamente
`workspace/`, no instala una instancia ni crea enlaces simbólicos. La
integración `--integrate-codex` sigue perteneciendo exclusivamente a proyectos
consumidores y crea un punto de descubrimiento separado para
`mem/workspace/`.

## Idioma

Usa español para el razonamiento comunicado, las conversaciones, la
documentación, los ejemplos y los diagnósticos dirigidos a personas. Conserva
en inglés los identificadores de programación, nombres de archivos, comandos,
claves de contratos, valores consumidos por herramientas y términos técnicos
establecidos. Un implementador puede cambiar el idioma de un proyecto
consumidor cuando lo documente expresamente en sus instrucciones locales.
