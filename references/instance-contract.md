# Instance contract

## Ownership

`mem/SKILL.md`, `mem/references/` y `mem/templates/` son symlinks al skill
canónico. `mem/workspace/` pertenece al proyecto consumidor y debe ser una
carpeta real, versionable y no sobrescribible por el bootstrap.

## Workspace layout

```text
workspace/
├── INDEX.md
└── records/
    └── YYYY-MM-DD--slug.md
```

`INDEX.md` es el punto de entrada de lectura. Mantiene un resumen de los
registros activos y una sección de registros retirados. Los registros no se
mueven al retirarse, de modo que sus enlaces sigan siendo estables.

## Record schema

Cada archivo de `records/` debe tener este front matter:

```yaml
---
id: YYYY-MM-DD--slug
type: decision | convention | lesson | project-context
status: active | retired
created: YYYY-MM-DD
updated: YYYY-MM-DD
scope: project
author: human | agent-name
sources: []
related: []
supersedes: null
superseded_by: null
---
```

`sources` enumera evidencia o archivos locales que sustentan la entrada.
`related` usa enlaces Markdown relativos o rutas de proyecto. Los campos de
reemplazo usan enlaces Markdown relativos; son `null` salvo cuando aplica.

El cuerpo incluye, como mínimo, una afirmación o decisión, su razón/evidencia y
sus implicaciones operativas. La plantilla de cada tipo establece el orden.

## Lifecycle

- Un registro nuevo comienza como `active`.
- Un cambio correctivo actualiza el mismo registro y su campo `updated`.
- Un cambio que invalida la conclusión crea un sucesor y retira el anterior.
- Un registro retirado se conserva, enlaza a su sucesor y deja de aparecer como
  activo en el índice.

## Agent integration

El bootstrap no modifica `AGENTS.md`. Para activar lectura selectiva en un
proyecto consumidor, copia el snippet canónico de
[agents-integration.md](agents-integration.md) y mantenlo como parte de las
instrucciones locales del proyecto.
