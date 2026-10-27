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
Esta condición es la precondición temporal para ejecutar la actualización; la
operación no crea tags ni commits. Después, una persona revisa y confirma el
commit documental posterior que actualiza el manifiesto. Ese commit avanza
`master` después del tag, por lo que `source.state: not-release-aligned` vuelve
a ser esperado y no invalida el release publicado.

El criterio editorial de publicación exige conservar el tag inmutable sobre el
merge de release, sincronizar `master` local con `origin/master` y comprobar
`vault.state: aligned` junto con `skill_version`, `source_revision` y
`source_tag` del manifiesto. No muevas ni fuerces un tag público para incluir
el commit documental posterior. Los consumidores usan `mem/vault/` y los
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

Para recontextualizar la evolución del proyecto, usa el dominio
`vault/20_domains/project-context/`: lee su `AGENTS.md`, `INDEX.md` y el
registro activo `2026-10-27--project-evolution-0-6-0.md`. Ese registro resume
la frontera de runtime, la evolución del CLI técnico, la gobernanza y el
protocolo de release; no sustituye las fuentes normativas ni autoriza cambios.

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

Las interfaces de soporte están confinadas por rol: una operación de fuente
resuelve únicamente `<source-root>/vault/` y una operación consumidora
únicamente `<project-root>/mem/vault/`. `ato-mem`, `scripts/vault.*` y el
bootstrap no aceptan rutas de vault arbitrarias; usa el contrato técnico de
[`references/runtime-boundary.md`](references/runtime-boundary.md) como fuente
normativa de ese límite.

## Alineación de integraciones

Cuando una tarea modifique `SKILL.md`, `references/`, un adaptador, un
empaquetador o sus pruebas, lee [`references/integration-alignment.md`](references/integration-alignment.md)
y [`references/capability-contract.md`](references/capability-contract.md) y,
si trata cambios persistentes, [`references/change-control-contract.md`](references/change-control-contract.md).
El adaptador de Microsoft 365 Copilot es una proyección subordinada del skill
principal: conserva su versión, semántica, provenance, scope, citas, límites
read-only y propiedad de la vault. Verifica también el contrato específico y
el ZIP antes de aceptar el cambio. Esta regla no autoriza editar los
`AGENTS.md` de proyectos consumidores ni crear tags o releases.

## Idioma

Usa español para el razonamiento comunicado, las conversaciones, la
documentación, los ejemplos y los diagnósticos dirigidos a personas. Conserva
en inglés los identificadores de programación, nombres de archivos, comandos,
claves de contratos, valores consumidos por herramientas y términos técnicos
establecidos. Un implementador puede cambiar el idioma de un proyecto
consumidor cuando lo documente expresamente en sus instrucciones locales.

## Convención de ramas del proyecto

Las ramas de trabajo de este repositorio usan el prefijo `codex/` y su nombre
descriptivo incluye la versión declarada en `VERSION` junto con el alcance del
cambio. El formato recomendado es `codex/<VERSION>-<scope-descriptivo>`; por
ejemplo, `codex/0.6.0-ato-mem-simplify-stabilize`. Esta convención pertenece
al flujo de trabajo de este proyecto y no forma parte del contrato de
`SKILL.md` ni de la interfaz del skill.
