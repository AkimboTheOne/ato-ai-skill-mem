# Migración manual de `vault/` a `wiki/`

Las versiones anteriores de `local-mem` guardaban la memoria en `vault/`.
Esta versión opera exclusivamente sobre `wiki/`; no consulta ni mueve la ruta
anterior. El layout interno permanece en formato `3`, así que el cambio de
ubicación no requiere transformar documentos.

## Antes de actualizar

1. Detén `local-mem` y cualquier herramienta que escriba en la instalación.
2. Si existe `vault/.local-mem.lock`, sigue las instrucciones de recuperación
   de la versión anterior. No retires un lock mientras su proceso siga activo.
3. Conserva una copia completa de la instalación y otra de `vault/`.
4. Ejecuta `./scripts/vault.sh check` con la versión anterior. Si falla,
   resuelve la estructura antes de migrar.

## Traslado

- Si `wiki/` aún no existe, renombra la carpeta completa `vault/` a `wiki/`.
  Conserva índices, instrucciones, plantillas, registros, recursos y archivos
  ocultos; no reorganices ni conviertas contenido en este paso.
- Si la instalación nueva ya contiene `wiki/`, no la reemplaces. Compara las
  dos carpetas y combina manualmente los archivos que quieras conservar. Ante
  una colisión, preserva ambas versiones hasta que una persona decida cómo
  resolverla.
- No combines `mem/vault/` de instalaciones consumidoras retiradas mediante
  esta guía; sus instrucciones siguen en [el histórico](history/README.md).

La skill no incluye un migrador automático. El traslado requiere revisión y
acción humana explícitas.

## Validación

Desde la raíz de la instalación nueva, ejecuta `./scripts/wiki.sh check` (o
`./scripts/wiki.ps1 check` en PowerShell). Revisa las instrucciones y los
índices activos, y confirma que los documentos necesarios estén presentes y
legibles. Conserva los respaldos hasta confirmar el resultado.
