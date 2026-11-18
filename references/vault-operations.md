# Operaciones de la vault

`SKILL.md` define activación, propiedad y autoridad. Los scripts de esta guía
resuelven una sola ruta: `vault/` junto a la skill. No reciben `--source`,
`--target`, `--vault` ni otra ruta.

## Diagnóstico

En macOS/Linux o PowerShell:

```sh
./scripts/vault.sh check
```

```powershell
./scripts/vault.ps1 check
```

`check` es de solo lectura. Valida el layout, los índices y los paquetes de
dominio; no repara ni reorganiza archivos.

## Layout y dominios

```sh
./scripts/vault.sh init-layout
./scripts/vault.sh create-domain --id arquitectura --title Arquitectura
```

`init-layout` crea únicamente elementos ausentes de la estructura básica.
`create-domain` crea un paquete en `20_domains/<id>/` y falla si ya existe.
Ambos comandos requieren una petición explícita y no sobrescriben contenido.
En PowerShell, usa `init-layout` y `create-domain -Id arquitectura -Title Arquitectura`.

El dominio inicial declara `routing.rules: []`. Completa propósito, límites,
vocabulario y fuentes antes de registrar conocimiento.

## Migración de registros raíz heredados

```sh
./scripts/vault.sh migration-plan
./scripts/vault.sh migration-apply --domain arquitectura --record 2026-10-25--decision.md
```

`migration-plan` crea propuestas revisables para los archivos Markdown en la
raíz heredada `records/` de la vault activa, sin moverlos ni clasificarlos.
`migration-apply` mueve un solo registro al dominio seleccionado y anota la
acción en `_indexes/action-log.md`; si no puede registrar el movimiento, lo
revierte. Estos comandos no leen ni migran una vault externa como `mem/vault/`;
para esa transición puntual, sigue la [guía de migración manual](legacy-vault-migration.md).

## Esquema y procedencia

Cada registro Markdown conserva su front matter, evidencia, enlaces y cadena
de reemplazo. Un cambio estructural requiere revisión explícita; no existe
routing automático. La persona decide el dominio cuando no hay uno claro.
