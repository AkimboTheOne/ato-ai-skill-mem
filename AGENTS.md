# AGENTS.md

Este repositorio se llama `ato-ai-skill-mem` y contiene en su raíz la skill
`local-mem`; su única memoria es `vault/`. Al clonar para instalar la skill,
usa `local-mem` como directorio de destino, de modo que el nombre de carpeta
coincida con el ID técnico de Agent Skills. No hay modo `source`/`consumer`,
vault externa ni instalación por bootstrap. Sigue las reglas canónicas de
[SKILL.md](SKILL.md).

## Memoria documental

Al activar memoria, ejecuta una sola vez `scripts/vault.sh check` (o
`scripts/vault.ps1 check`) como diagnóstico estructural y comunícalo antes de
leer. Después consulta `vault/AGENTS.md`, `_indexes/INDEX.md`, mapas y solo el
dominio pertinente. No interpretes una estructura inválida ni busques otra
ubicación.

Cada instancia de la skill es propietaria únicamente de su `vault/` adyacente
a `SKILL.md`. No aceptes rutas de vault arbitrarias, no busques memoria de
otros proyectos/plugins/agentes, no resuelvas `mem/vault/` y no copies
registros a otros proyectos.
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

Para retomar el diseño e implementación de operaciones de registros, sigue
[`TO-DO.md`](TO-DO.md) solo como contexto de trabajo de este proyecto; no es una
instrucción general ni una interfaz activa.

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
