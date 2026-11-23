# Proyecto

`ato-ai-skill-mem` es el repositorio fuente de la skill Agent Skills
`local-mem`. Mantiene sus instrucciones portables, herramientas de desarrollo,
plantillas, contratos y validaciones.

La documentación propia del repositorio vive en `doc/`. La carpeta `wiki/`
solo conserva el layout base vacío que acompaña a la skill al instalarla; no
es el archivo de decisiones ni el historial de este proyecto.

## Ámbitos

- `SKILL.md`, `references/`, `scripts/` y `templates/` definen y soportan la
  skill.
- `doc/` explica el proyecto, la memoria y la skill para sus mantenedores.
- `wiki/` aporta carpetas, índices, plantillas y reglas generales como punto
  de partida para una instalación.
- `doc/memory/history/` conserva los datos de contexto que anteriormente se
  guardaban en la wiki del repositorio.

La integración con otras superficies anfitrionas permanece histórica; el
repositorio no declara sincronización ni instalación automática.

## Skills y ámbitos

`local-mem`, definida en [`SKILL.md`](../../SKILL.md), es la skill portable
del producto. En cada instalación administra solo la `wiki/` adyacente a su
propio `SKILL.md`. La `wiki/` de este repositorio es únicamente su layout base
vacío.

`project-doc`, definida en
[`project-doc/SKILL.md`](../../.agents/skills/project-doc/SKILL.md),
es una ayuda local para mantener `doc/`. No administra `wiki/` ni forma parte
del paquete portable de `local-mem`.

Cada skill mantiene su SemVer por separado: `VERSION` en la raíz corresponde
a `local-mem`; `.agents/skills/project-doc/VERSION` corresponde a
`project-doc`. `WIKI_FORMAT` versiona únicamente el layout de memoria y no se
deriva de ninguna de esas versiones.
