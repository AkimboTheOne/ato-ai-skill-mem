# Límite técnico de runtime

Las herramientas de soporte operan únicamente sobre la vault que corresponde
al rol explícito de la invocación. Una ruta existente no es una autorización
suficiente.

## Roles y raíces

| Rol | Entrada autorizada | Vault operativa |
| --- | --- | --- |
| `source` | `SOURCE_ROOT` | `SOURCE_ROOT/vault/` |
| `consumer` | `PROJECT_PATH` | `PROJECT_PATH/mem/vault/` |

Los scripts usan `--source` o `--target PROJECT_PATH`. El CLI Python usa las
mismas opciones por comando. `--source` no recibe una vault: recibe la raíz
del repositorio fuente. `--target` no recibe una vault: recibe la raíz del
proyecto consumidor.

`--vault` y `-Vault` no son interfaces autorizadas. Su uso debe fallar con un
error de uso antes de leer o escribir archivos.

## Reglas de resolución

- `source` requiere `VERSION`, `VAULT_FORMAT`, `scripts/` y
  `vault/.ato-ai-skill-mem-version.yml` con `vault_kind: source`.
- `consumer` requiere `mem/` y `mem/vault/` locales. Si existe el manifiesto,
  no puede declarar `vault_kind: source`.
- La raíz de la vault y los componentes fijos `mem/` y `mem/vault/` no pueden
  ser symlinks.
- Un proyecto consumidor no puede ser la fuente ni estar dentro de la raíz de
  la fuente.
- La resolución devuelve una ruta canónica; las operaciones posteriores no
  reciben una ruta elegida libremente por el usuario.
- Los archivos y directorios simbólicos internos no se siguen.

## Efectos

El CLI Python es read-only. `check`, `find`, `relate`, `build` y `retrieve`
solo leen la vault resuelta.

Los scripts pueden mutar layout o datos únicamente dentro de la vault resuelta
por el rol. Ningún comando puede escribir en el repositorio fuente desde un
rol consumidor ni en un proyecto consumidor desde el rol fuente.

Este límite no sustituye los permisos del sistema operativo ni constituye un
sandbox de procesos. Es una prohibición de ámbito implementada por contrato,
resolución de rutas, validación de rol y pruebas de no escape.
