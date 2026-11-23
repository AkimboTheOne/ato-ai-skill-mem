# ato-ai-skill-mem

Este repositorio mantiene el código fuente de la skill `local-mem` y la
documentación del proyecto. La memoria real de una instalación se guarda en
`wiki/`; en este repositorio, `wiki/` contiene únicamente la estructura base
vacía y sus reglas generales.

## Documentación

- [Índice de documentación](doc/README.md)
- [Proyecto](doc/project/README.md)
- [Memoria y layout base](doc/memory/README.md)
- [Skill e instalación](doc/skill/README.md)
- [Guía de instalación y uso](doc/skill/installation.md)

Los registros que antes estaban en `wiki/` se conservan como historia en
[`doc/memory/history/`](doc/memory/history/). No forman parte de la memoria
activa ni se incluyen como datos iniciales de una instalación.

## Instalación

Clona el repositorio con `local-mem` como carpeta de destino, para que su
nombre coincida con el ID técnico de Agent Skills:

```sh
git clone git@github.com:AkimboTheOne/ato-ai-skill-mem.git local-mem
```

Consulta la [guía completa](doc/skill/installation.md) para copiar los
componentes, usar la skill y validar sus metadatos. No copies configuración local (`.codex/`): exclúyela junto con metadatos Git (`.git`), pruebas y
artefactos de desarrollo.

Si actualizas una instalación que aún guarda su memoria en `vault/`, sigue la
[guía de migración manual](references/legacy-wiki-migration.md). La skill no
consulta ni traslada esa ruta automáticamente.
