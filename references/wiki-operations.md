# Operaciones de la wiki

`SKILL.md` define activación, propiedad y autoridad. Los scripts de esta guía
resuelven una sola ruta: `wiki/` junto a la skill. No reciben `--source`,
`--target`, `--wiki` ni otra ruta.

## Diagnóstico

En macOS/Linux o PowerShell:

```sh
./scripts/wiki.sh check
```

```powershell
./scripts/wiki.ps1 check
```

`check` es de solo lectura. Valida el layout, los índices y los paquetes de
dominio; no repara ni reorganiza archivos.

## Layout y dominios

```sh
./scripts/wiki.sh init-layout
./scripts/wiki.sh create-domain --id arquitectura --title Arquitectura
```

`init-layout` crea únicamente elementos ausentes de la estructura básica.
`create-domain` crea un paquete en `20_domains/<id>/` y falla si ya existe.
Ambos comandos requieren una petición explícita y no sobrescriben contenido.
En PowerShell, usa `init-layout` y `create-domain -Id arquitectura -Title Arquitectura`.

El dominio inicial declara `routing.rules: []`. Completa propósito, límites,
vocabulario y fuentes antes de registrar conocimiento.
Para nombrar dominios nuevos, sigue el criterio de [nombres de contenido](content-operations.md#nombres-para-contenido-nuevo).

## Migración de registros raíz heredados

```sh
./scripts/wiki.sh migration-plan
./scripts/wiki.sh migration-apply --domain arquitectura --record 2026-10-25--decision.md
```

`migration-plan` crea propuestas revisables para los archivos Markdown en la
raíz heredada `records/` de la wiki activa, sin moverlos ni clasificarlos.
`migration-apply` mueve un solo registro al dominio seleccionado y anota la
acción en `_indexes/action-log.md`; si no puede registrar el movimiento, lo
revierte. Estos comandos no leen ni migran instalaciones retiradas en
`mem/vault/`; para actualizar una instalación antigua con `vault/`, sigue la
[guía de migración manual](legacy-wiki-migration.md).

## Esquema y procedencia

Cada registro Markdown conserva su front matter, evidencia, enlaces y cadena
de reemplazo. Un cambio estructural requiere revisión explícita; no existe
routing automático. La persona decide el dominio cuando no hay uno claro.

## Contenido

Para los flujos y el asistente Python de contenido, consulta [content-operations.md](content-operations.md). Bash y PowerShell conservan las operaciones de instancia y diagnóstico existentes.

Las operaciones de escritura de instancia participan en el lock compartido; consulta [coordinación de escrituras](content-operations.md#coordinación-de-escrituras) antes de recuperar una operación interrumpida.
