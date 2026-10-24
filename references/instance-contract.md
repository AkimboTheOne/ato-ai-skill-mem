# Contrato de instancia

## Propiedad

`mem/SKILL.md`, `mem/references/` y `mem/templates/` son enlaces simbólicos al skill
canónico. `mem/workspace/` pertenece al proyecto consumidor y debe ser una
carpeta real, versionable y no sobrescribible por el bootstrap.

## Estructura del workspace

```text
workspace/
├── INDEX.md
├── .ato-ai-skill-mem-version.yml
└── records/
    └── YYYY-MM-DD--slug.md
```

## Alineación de versión

`VERSION` en la raíz canónica es la versión SemVer declarada y
`WORKSPACE_FORMAT` es el entero que identifica el formato de datos soportado.
Un release válido debe estar en `master` y tener el tag Git exacto
`v<VERSION>` en el mismo commit. El bootstrap no consulta la red: valida solo
el checkout local.

`.ato-ai-skill-mem-version.yml` pertenece al workspace y registra la última
versión, revisión y `workspace_format` del skill que lo inicializó o actualizó
de forma explícita. Es metadata operativa, no un registro de memoria. El
bootstrap lo crea si no existe; `--update-workspace` solo lo renueva desde una
fuente `release-aligned`, sin tocar el índice ni los registros.

El formato `1` se conserva durante `0.x` y `1.x`. Un workspace anterior sin
manifiesto, o sin `workspace_format`, se interpreta como formato heredado `1`
y sigue siendo operable sin migración. Un formato distinto requiere diagnóstico
y confirmación humana antes de cualquier rutina de migración; esas rutinas no
forman parte del bootstrap.

`INDEX.md` es el punto de entrada de lectura. Mantiene un resumen de los
registros activos y una sección de registros retirados. Los registros no se
mueven al retirarse, de modo que sus enlaces sigan siendo estables.

## Esquema de registros

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

## Ciclo de vida

- Un registro nuevo comienza como `active`.
- Un cambio correctivo actualiza el mismo registro y su campo `updated`.
- Un cambio que invalida la conclusión crea un sucesor y retira el anterior.
- Un registro retirado se conserva, enlaza a su sucesor y deja de aparecer como
  activo en el índice.

## Integración del agente

El bootstrap no modifica `AGENTS.md`. Para activar lectura selectiva en un
proyecto consumidor, copia el bloque canónico de
[agents-integration.md](agents-integration.md) y mantenlo como parte de las
instrucciones locales del proyecto.
