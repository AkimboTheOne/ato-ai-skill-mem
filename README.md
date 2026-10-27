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
│       ├── 99_runtime/rag/       # extensión técnica opcional
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

`VERSION` declara la versión SemVer y `VAULT_FORMAT` el formato de datos. La versión de desarrollo actual es `0.6.0` y el formato actual es `3`. Un release válido requiere `master`, checkout limpio y el tag `v<VERSION>` sobre el mismo commit.

La política editorial clasifica `X` como cambio no retrocompatible, `Y` como
nueva capacidad pública retrocompatible y `Z` como corrección o ajuste sin
nueva capacidad pública. El detalle canónico está en
[SKILL.md](SKILL.md#política-editorial-semver); `VAULT_FORMAT` se versiona y
migra por separado.

Consulta la vault de fuente con:

```sh
./scripts/bootstrap.sh --source-status
```

`--update-source-vault` solo actualiza el manifiesto desde un release válido;
no crea commits ni tags. Después de confirmar el commit documental, es normal
que `source.state` vuelva a `not-release-aligned`: `master` queda después del
tag, mientras el release sigue identificado por el tag inmutable y la vault
queda `aligned`. No fuerces el tag para eliminar esa diferencia.

## Modos de uso

La matriz canónica de modos, propiedad, autoridad, precondiciones y efectos
está en [references/vault-operations.md](references/vault-operations.md).

En resumen:

- Los diagnósticos (`--status`, `--contextualize` y `--source-status`) son de
  solo lectura.
- La inicialización, actualización, migración e integración requieren la
  operación explícita correspondiente y no sobrescriben contenido existente.
- Las operaciones source usan `vault/`; las operaciones consumer usan
  `mem/vault/` y no comparten registros.
- `VAULT_FORMAT=3` permanece sin cambios en `0.6.0`; no se añade routing,
  sincronización automática ni estado persistente oculto.

## CLI Python complementario

El paquete Python `ato-ai-mem` añade el comando `ato-mem` para análisis
determinista y de solo lectura. No sustituye `scripts/vault.sh` ni
`scripts/vault.ps1`: esos scripts siguen siendo la autoridad para layout,
migraciones y operaciones estructurales.

Instalación recomendada desde un checkout:

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install .
```

Para verificar la instalación en un entorno temporal, ejecuta
`sh tests/test-install.sh`. Los comandos, formatos, límites y códigos de
salida del CLI están en [references/python-cli.md](references/python-cli.md).
La interfaz solo lee vaults formato `3`, no crea cachés ni índices y no accede
a la red. El roadmap gobernado hacia retrieval semántico y RAG está en
[references/retrieval-roadmap.md](references/retrieval-roadmap.md).

El CLI y los scripts resuelven el ámbito por rol: `--source` opera solo sobre
`SOURCE_ROOT/vault/` y `--target PROJECT_PATH` solo sobre
`PROJECT_PATH/mem/vault/`. `--vault` y `-Vault` no están permitidos. El
contrato técnico de confinamiento está en
[references/runtime-boundary.md](references/runtime-boundary.md).

`ato-mem` es una base técnica de bajo nivel: entrega diagnósticos, chunks y
resultados con provenance para consumidores posteriores. El futuro cerebro que
ensamble contexto o genere respuestas será un componente externo y no forma
parte de este paquete.

El layout reserva `99_runtime/rag/` para una futura persistencia gobernada de
índices. La extensión es opcional y no convierte esos artefactos en memoria
canónica; el contrato de la reserva está en
[references/instance-contract.md](references/instance-contract.md).

## Límites

No incluye todavía RAG operativo, bases vectoriales, búsqueda semántica,
clasificación por confianza, aprendizaje adaptativo, ejecución en segundo
plano ni sincronización entre vaults. `99_runtime/rag/` es únicamente una
reserva técnica opcional para una fase posterior. Un futuro cerebro externo
puede consumir una o más vaults, pero no recibe autoridad implícita para
modificarlas.

Consulta [SKILL.md](SKILL.md) para el comportamiento canónico, [references/instance-contract.md](references/instance-contract.md) para el contrato de instancia y [references/agents-integration.md](references/agents-integration.md) para la integración manual de agentes.

La guía detallada de cada método está en [references/vault-operations.md](references/vault-operations.md).
