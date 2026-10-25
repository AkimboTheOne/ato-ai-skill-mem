# ato-ai-skill-mem

`ato-ai-skill-mem` administra memoria contextual, local y versionable para proyectos y agentes. La memoria es Markdown legible por personas: no captura conversaciones, no infiere aprendizajes para persistirlos y no es un cerebro.

## Modelo

El repositorio contiene la fuente canónica del skill. Un consumidor instala una instancia híbrida en `mem/`; los artefactos canónicos son enlaces simbólicos y la vault es una carpeta local, real y versionable.

```text
consumer-project/
├── .agents/skills/ato-ai-project-mem/   # adaptador opcional de Codex
├── mem/
│   ├── SKILL.md -> fuente/SKILL.md
│   ├── scripts/ -> fuente/scripts/
│   ├── templates/ -> fuente/templates/
│   └── vault/                            # propiedad del consumidor
│       ├── AGENTS.md
│       ├── 00_inbox/
│       ├── 10_areas/
│       ├── 20_domains/
│       ├── 30_resources/ … 60_exports/
│       ├── _indexes/ y _maps/
│       └── _templates/
└── AGENTS.md                             # nunca modificado por bootstrap
```

El vault de este repositorio es una vault de fuente. No comparte contenido ni se sincroniza automáticamente con vaults consumidoras.

## Vault modular

El formato `3` organiza la memoria como un módulo contextual portable:

- `vault/AGENTS.md` define reglas maestras no anulables.
- `20_domains/<id>/` es la única unidad portable: incluye `AGENTS.md`, `domain.yml`, índice, registros y recursos.
- `10_areas/` contiene mapas transversales; no crea una segunda jerarquía de paquetes.
- `00_inbox/decisions-pending/` conserva propuestas que requieren decisión de un operador.
- `_indexes/action-log.md` registra movimientos explícitos.

Los AGENTS de dominio pueden añadir o restringir contexto, pero no habilitan inferencia adaptativa, sincronización automática, sobrescrituras ni movimientos sin trazabilidad.

## Instalación y diagnóstico

macOS/Linux:

```sh
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project --integrate-codex
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project --status
```

Windows PowerShell:

```powershell
.\scripts\bootstrap.ps1 -Target C:\path\to\consumer-project
.\scripts\bootstrap.ps1 -Target C:\path\to\consumer-project -IntegrateCodex
.\scripts\bootstrap.ps1 -Target C:\path\to\consumer-project -Status
```

El bootstrap crea el scaffold de formato `3` solo en vaults nuevas y nunca reemplaza contenido existente. Vaults de formatos anteriores requieren migración explícita.

Una vault de formato `2` se migra en dos fases: `--migrate-vault-format` crea
el layout y las propuestas sin cambiar el manifiesto; después de mover cada
registro raíz de forma explícita, `--migrate-vault-format --finalize` archiva
el `INDEX.md` heredado en `40_archive/legacy-root-INDEX.md` y actualiza el
manifiesto a formato `3`. La finalización rechaza registros pendientes o un
archivo de archivo existente.

## CLI de vault

La CLI es determinista y no clasifica contenido por significado.

```sh
./scripts/vault.sh init-layout --vault /ruta/a/vault
./scripts/vault.sh create-domain --vault /ruta/a/vault --id arquitectura --title Arquitectura
./scripts/vault.sh check --vault /ruta/a/vault
./scripts/vault.sh migration-plan --vault /ruta/a/vault
./scripts/vault.sh migration-apply --vault /ruta/a/vault --domain arquitectura --record 2026-10-25--decision.md
```

PowerShell usa los mismos comandos:

```powershell
.\scripts\vault.ps1 init-layout -Vault C:\ruta\a\vault
.\scripts\vault.ps1 create-domain -Vault C:\ruta\a\vault -Id arquitectura -Title Arquitectura
.\scripts\vault.ps1 check -Vault C:\ruta\a\vault
```

La migración de formato usa el bootstrap equivalente:

```sh
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project --migrate-vault-format
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project --migrate-vault-format --finalize
```

```powershell
.\scripts\bootstrap.ps1 -Target C:\path\to\consumer-project -MigrateVaultFormat
.\scripts\bootstrap.ps1 -Target C:\path\to\consumer-project -MigrateVaultFormat -Finalize
```

`migration-plan` crea propuestas para registros raíz heredados; no los asigna por similitud semántica. `migration-apply` mueve un registro seleccionado, evita sobrescrituras y añade una entrada auditable al log.

El baseline valida `routing.rules: []`; todavía no ejecuta reglas de routing automáticas. Cualquier extensión futura deberá usar únicamente metadata explícita y ampliar de forma conjunta el contrato, la CLI y sus pruebas.

## Versiones y release

`VERSION` declara la versión SemVer y `VAULT_FORMAT` el formato de datos. La versión actual es `0.3.0` y el formato actual es `3`. Un release válido requiere `master`, checkout limpio y el tag `v<VERSION>` sobre el mismo commit.

Consulta la vault de fuente con:

```sh
./scripts/bootstrap.sh --source-status
```

`--update-source-vault` solo actualiza el manifiesto desde un release válido; no crea commits ni tags.

## Límites

No incluye RAG, bases vectoriales, búsqueda semántica, clasificación por confianza, aprendizaje adaptativo, ejecución en segundo plano ni sincronización entre vaults. Un futuro cerebro puede consumir una o más vaults, pero no recibe autoridad implícita para modificarlas.

Consulta [SKILL.md](SKILL.md) para el comportamiento canónico, [references/instance-contract.md](references/instance-contract.md) para el contrato de instancia y [references/agents-integration.md](references/agents-integration.md) para la integración manual de agentes.

La guía detallada de cada método está en [references/vault-operations.md](references/vault-operations.md).
