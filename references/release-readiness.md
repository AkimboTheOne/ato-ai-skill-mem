# Preparación de release

La versión se clasifica sobre el diff final respecto del último release. Una
rama no fija SemVer. `VERSION` describe la skill y `VAULT_FORMAT` el layout;
solo se cambia el formato cuando cambia el contrato de datos.

La política editorial clasifica `major` como cambio público no retrocompatible,
`minor` como capacidad pública retrocompatible y `patch` como corrección,
documentación, pruebas o refactor interno. La misma convención se aplica
durante `0.x`. Este refactor elimina interfaces públicas anteriores; el gate
debe evaluarlo como cambio incompatible y actualizar `VERSION` solo después de
clasificar el diff completo.

## Preflight

El preflight es de solo lectura:

```sh
./scripts/release-check.sh --format json
```

Comprueba versión y formato, rama `master`, árbol limpio, tag `v<VERSION>` en
`HEAD`, sincronización con `origin/master` y `scripts/vault.sh check`. No crea
tags, commits ni pushes y no modifica `vault/`. Antes de crear el tag, los
estados `tag` y `head_tag` pueden quedar pendientes.

## Gate de publicación

1. Preparar y validar el candidato en una rama `codex/<scope>`.
2. Comparar el diff completo con el último tag promovido y clasificar SemVer.
3. Actualizar `VERSION` en el candidato y repetir validaciones.
4. Integrar en `master` con árbol limpio y sincronizarlo con `origin/master`.
5. Crear el tag inmutable `v<VERSION>` sobre el commit integrado.
6. Ejecutar el preflight y confirmar que queda listo.

La vault está incluida en la instalación de la skill y no requiere una
actualización documental posterior al tag. No muevas ni fuerces tags públicos.
