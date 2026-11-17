# Contrato de la instalación

## Una raíz, una vault

La carpeta que contiene `SKILL.md` es la raíz operativa de la skill. Debe
contener `vault/`, `scripts/` y `templates/`. La skill consulta exclusivamente
esa `vault/`; no hay configuración de rol, ruta de destino ni manifiesto de
instancia.

Al copiar o instalar la skill, conserva la carpeta completa y su `vault/`.
Una ruta ausente, un symlink de `vault/` o una estructura incompatible son
errores que detienen la consulta; el agente no busca otra ubicación ni crea
una nueva vault automáticamente.

## Formato de datos

`VAULT_FORMAT` declara el layout. El formato `3` contiene:

- `AGENTS.md` con las reglas maestras;
- `00_inbox/`, `10_areas/`, `20_domains/`, `30_resources/`, `40_archive/`,
  `50_daily/` y `60_exports/`;
- `_indexes/`, `_maps/` y `_templates/`.

Una vault de formato `3` no conserva `INDEX.md` en la raíz. La navegación
empieza en `_indexes/INDEX.md`. Cada dominio en `20_domains/<id>/` incluye
`domain.yml`, `AGENTS.md`, `INDEX.md`, `records/` y `resources/`.

`VERSION` y `VAULT_FORMAT` son dimensiones independientes. No existe un
manifiesto separado que repita la versión o la ubicación. Una actualización
que cambie el layout debe definir una migración explícita y reversible antes
de modificar `VAULT_FORMAT`.

## Dominio

`domain.yml` incluye `format`, `id`, `title`, `status`, `scope`, `areas` y
`routing`. El baseline es `routing.rules: []`. Los dominios añaden contexto,
pero no autoridad de escritura ni clasificación automática.

## Registro

Los registros usan `templates/records/` y nombres
`YYYY-MM-DD--slug.md`. Su front matter conserva tipo, estado, fecha, alcance,
autor, fuentes, relaciones y cadena de reemplazo. Los registros retirados se
conservan enlazados a su sucesor; no se borran para resolver conflictos.

Los directorios para RAG, si aparecen en una versión histórica de la vault,
no son parte del baseline actual ni una autorización para crear índices.
