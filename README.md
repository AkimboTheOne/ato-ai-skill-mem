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

El repositorio también expone `.agents/skills/ato-ai-source-mem/`, un adaptador
de descubrimiento exclusivo de la vault fuente. Su función es diagnosticar,
leer y proponer sobre `vault/` cuando una tarea necesita memoria del producto;
no instala consumidores ni recibe autoridad adicional para cambiar datos. El
adaptador de Codex de un consumidor, en cambio, vive en
`.agents/skills/ato-ai-project-mem/` dentro del proyecto consumidor y opera
solo sobre `mem/vault/`.

## Vault modular

El formato `3` organiza la memoria como un módulo contextual portable:

- `vault/AGENTS.md` define reglas maestras no anulables.
- `20_domains/<id>/` es la única unidad portable: incluye `AGENTS.md`, `domain.yml`, índice, registros y recursos.
- `10_areas/` contiene mapas transversales; no crea una segunda jerarquía de paquetes.
- `00_inbox/decisions-pending/` conserva propuestas que requieren decisión de un operador.
- `_indexes/action-log.md` registra movimientos explícitos.

Los AGENTS de dominio pueden añadir o restringir contexto, pero no habilitan inferencia adaptativa, sincronización automática, sobrescrituras ni movimientos sin trazabilidad.

El contrato operativo, incluida la activación contextual y la autoridad de
cambios, está en [SKILL.md](SKILL.md).

## Instalación y diagnóstico

macOS/Linux:

```sh
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project --init
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project --contextualize
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project --integrate-codex
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project --status
```

Windows PowerShell:

```powershell
.\scripts\bootstrap.ps1 -Target C:\path\to\consumer-project
.\scripts\bootstrap.ps1 -Target C:\path\to\consumer-project -Init
.\scripts\bootstrap.ps1 -Target C:\path\to\consumer-project -Contextualize
.\scripts\bootstrap.ps1 -Target C:\path\to\consumer-project -IntegrateCodex
.\scripts\bootstrap.ps1 -Target C:\path\to\consumer-project -Status
```

El bootstrap crea el scaffold de formato `3` solo en vaults nuevas y nunca reemplaza contenido existente. Vaults de formatos anteriores requieren migración explícita.

La inicialización informa `vault.initialization.state` (`new` o `existing`) y
un inventario estructural de agentes, índices, dominios y datos. `--init`
exige que la vault esté ausente; `--contextualize` solo muestra el wizard
guiado. Ninguna de esas operaciones persiste un estado de contextualización.
El agente debe acordar propósito, lectura contextual, gestión de datos y
autorización antes de crear memoria.

La CLI, los efectos de cada método y los pasos detallados de migración están
en [references/vault-operations.md](references/vault-operations.md). El
contrato de datos y layout está en
[references/instance-contract.md](references/instance-contract.md).

## Versiones y release

`VERSION` declara la versión SemVer y `VAULT_FORMAT` el formato de datos. La versión de desarrollo actual es `0.5.0` y el formato actual es `3`. Un release válido requiere `master`, checkout limpio y el tag `v<VERSION>` sobre el mismo commit.

Consulta la vault de fuente con:

```sh
./scripts/bootstrap.sh --source-status
```

`--update-source-vault` solo actualiza el manifiesto desde un release válido;
no crea commits ni tags. Después de confirmar el commit documental, es normal
que `source.state` vuelva a `not-release-aligned`: `master` queda después del
tag, mientras el release sigue identificado por el tag inmutable y la vault
queda `aligned`. No fuerces el tag para eliminar esa diferencia.

## Matriz de modos

| Modo | Propiedad | Efecto | Autoridad y precondición |
| --- | --- | --- | --- |
| `--contextualize` / `--status` | consumidor o fuente | diagnóstico de solo lectura | activación contextual; no modifica archivos |
| `--init` | consumidor | crea el scaffold de una vault ausente | petición explícita; el destino debe estar ausente |
| `--update-vault` | consumidor | actualiza solo el manifiesto compatible | petición explícita, checkout fuente `release-aligned` |
| `--source-status` | fuente | diagnostica la vault `vault/` | activación contextual; no admite `--target` |
| `--update-source-vault` | fuente | actualiza solo el manifiesto de la fuente | checkout limpio en `master` con `v<VERSION>` en `HEAD` |
| `--migrate-vault-format` | consumidor | prepara o finaliza la migración 2 → 3 | petición explícita y resolución humana de registros |
| `--migrate-workspace-to-vault` | consumidor o fuente | mueve el almacenamiento heredado | petición explícita; no puede existir el destino |
| `--integrate-codex` | consumidor | crea o valida el adaptador local | instalación; nunca sobrescribe configuración existente |

Los modos de actualización y migración no clasifican contenido, no sincronizan
vaults y no modifican `AGENTS.md`. `VAULT_FORMAT=3` permanece sin cambios en
la versión `0.5.0`.

El diagnóstico expone claves estables para `source.state`, `vault.state`,
`vault.context.state` y `vault.context.next_step`. Bash y PowerShell deben
producir las mismas decisiones para los mismos escenarios.

## Límites

No incluye RAG, bases vectoriales, búsqueda semántica, clasificación por confianza, aprendizaje adaptativo, ejecución en segundo plano ni sincronización entre vaults. Un futuro cerebro puede consumir una o más vaults, pero no recibe autoridad implícita para modificarlas.

Consulta [SKILL.md](SKILL.md) para el comportamiento canónico, [references/instance-contract.md](references/instance-contract.md) para el contrato de instancia y [references/agents-integration.md](references/agents-integration.md) para la integración manual de agentes.

La guía detallada de cada método está en [references/vault-operations.md](references/vault-operations.md).
