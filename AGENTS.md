# AGENTS.md

Este repositorio es la instalación de la skill `ato-ai-skill-mem`; su única
memoria es `vault/`. No hay modo `source`/`consumer`, vault externa ni
instalación por bootstrap. Sigue las reglas canónicas de [SKILL.md](SKILL.md).

## Memoria documental

Al activar memoria, ejecuta una sola vez `scripts/vault.sh check` (o
`scripts/vault.ps1 check`) como diagnóstico estructural y comunícalo antes de
leer. Después consulta `vault/AGENTS.md`, `_indexes/INDEX.md`, mapas y solo el
dominio pertinente. No interpretes una estructura inválida ni busques otra
ubicación.

La raíz de la skill es propietaria de `vault/`. No aceptes rutas de vault
arbitrarias, no resuelvas `mem/vault/` y no copies registros a otros proyectos.
La integración con otras superficies anfitrionas permanece histórica; no
afirmes que existe sincronización o instalación automática.

Las escrituras requieren una petición humana explícita. No guardes
transcripciones, no infieras memoria persistente ni crees estado oculto.

## Contratos y release

Las operaciones estructurales de la vault están en
[`references/vault-operations.md`](references/vault-operations.md). Para
preparar publicaciones, sigue
[`references/release-readiness.md`](references/release-readiness.md); esa guía
no autoriza por sí sola tags ni releases.

Los diseños retirados de instalación consumidora, adaptadores y CLI están en
[`references/history/README.md`](references/history/README.md) y no describen
interfaces activas.

## Gobernanza

Cuando `ato-ai-skill-governance` esté disponible, úsala en planificación,
diseño, validación y simplificación. Conserva auditabilidad humana y detén la
automatización si el proceso no es estable. La skill de gobernanza no es una
dependencia runtime.

## Idioma y ramas

Usa español para documentación, conversaciones y diagnósticos dirigidos a
personas. Conserva en inglés los identificadores, rutas, comandos y valores de
contrato consumidos por herramientas.

Las ramas de trabajo usan `codex/<scope-descriptivo>`. La SemVer se decide en
el gate de integración sobre el diff final, no al crear la rama.
