# Operaciones de la vault modular

Esta guía describe la interfaz determinista del formato `3`. Sirve tanto para
una vault de consumidor (`mem/vault/`) como para la vault fuente (`vault/`),
pero nunca convierte una en la otra ni comparte sus datos.

Las operaciones cambian archivos solo cuando se invocan expresamente. No
clasifican contenido por significado, no usan historial como señal y no
sincronizan vaults.

`SKILL.md` define activación, propiedad, modos y autorización. Esta referencia
describe únicamente comandos, efectos y fallos; `check` es de solo lectura y
los demás métodos mutan solo cuando se solicitan conforme al contrato.

La supervisión no añade un comando: combina `check` con una revisión
documental de todos los `AGENTS.md` e `INDEX.md` de los dominios cuando la
persona la solicita, cuando termina una operación estructural o cuando el
diagnóstico detecta una inconsistencia. El resultado distingue validaciones y
recomendaciones de cualquier cambio persistente.

## Interfaces equivalentes

En macOS y Linux:

```sh
./scripts/vault.sh <comando> --vault /ruta/a/vault [argumentos]
```

En Windows PowerShell:

```powershell
.\scripts\vault.ps1 <comando> -Vault C:\ruta\a\vault [argumentos]
```

La ruta indicada debe existir. El bootstrap crea una vault nueva en
`mem/vault/`; después, la CLI administra su layout. Para la fuente se pasa
explícitamente la ruta `vault/`; jamás `--target .` al bootstrap.

El bootstrap sin una operación explícita conserva la instalación compatible y
reporta el estado contextual. `--init` (`-Init`) es una transición estricta
para una vault ausente. `--contextualize` (`-Contextualize`) y `--status`
(`-Status`) son diagnósticos de solo lectura; no crean enlaces, scaffold,
manifiestos ni registros.

## Autoridad por operación

| Operación | Lectura o cambio | Precondición principal |
| --- | --- | --- |
| `--status`, `--contextualize` | solo lectura | consumidor resoluble |
| `--source-status` | solo lectura | fuente resoluble; no admite `--target` |
| `--init` | crea scaffold | consumidor sin vault |
| `--update-vault` | cambia solo el manifiesto | fuente `release-aligned` y formato compatible |
| `--update-source-vault` | cambia solo el manifiesto fuente | `master`, checkout limpio y tag en `HEAD` |
| `--migrate-vault-format` | prepara o finaliza migración | petición explícita y registros resueltos |
| `--migrate-workspace-to-vault` | mueve `mem/workspace` a `mem/vault` | consumidor, destino ausente y manifiesto heredado válido |
| `--migrate-source-workspace-to-vault` | mueve `workspace/` a `vault/` | fuente, destino ausente y manifiesto heredado válido |
| `--integrate-codex` | crea o valida integración | instalación; no sobrescribe rutas existentes |

Las dos implementaciones (`bootstrap.sh` y `bootstrap.ps1`) comparten estas
claves y decisiones contractuales. La matriz portable de escenarios está en
`tests/fixtures/bootstrap-contract.tsv`; no constituye memoria persistente ni
habilita routing.

## Diagnóstico contextual

El diagnóstico imprime claves estables para `vault.initialization.state`,
`vault.context.state` y `vault.context.next_step`, además del inventario de
`AGENTS.md`, índices, dominios, metadata y datos. El estado `blocked` remite a
migración, actualización o resolución de propiedad/versiones; el bootstrap no
interpreta datos para superar el bloqueo.

Las claves de inventario son `vault.context.root_agents`,
`vault.context.indexes`, `vault.context.maps_index`,
`vault.context.action_log`, `vault.context.domains.total`,
`vault.context.domains.with_agents`, `vault.context.domains.with_indexes`,
`vault.context.domains.with_metadata`, `vault.data.records`,
`vault.data.pending` y `vault.data.resources`.

El wizard que sigue al diagnóstico tiene cuatro fases: definir expectativas,
leer contexto declarado, acordar gestión de datos y validar/autorizar. Es un
flujo del agente y la persona, no un archivo persistido ni una sesión
interactiva del shell.

## `init-layout`

```sh
./scripts/vault.sh init-layout --vault /ruta/a/vault
```

Crea solo los directorios y archivos faltantes del scaffold: `00_inbox/`,
`10_areas/`, `20_domains/`, los directorios compartidos, `_indexes/`,
`_maps/`, `_templates/`, el `AGENTS.md` maestro y los índices vacíos. Copia
las plantillas locales únicamente si todavía no existen. Es idempotente y no
sobrescribe personalizaciones ni registros.

Úsalo al inicializar una vault vacía o para completar un layout incompleto por
petición humana. No sustituye una migración de formato ni reclasifica datos.

## `create-domain`

```sh
./scripts/vault.sh create-domain --vault /ruta/a/vault \
  --id arquitectura --title Arquitectura
```

Crea el único paquete portable: `20_domains/<id>/`. Incluye `domain.yml`,
`AGENTS.md`, `INDEX.md`, `records/` y `resources/`. El identificador debe usar
minúsculas, dígitos y guiones, tener entre 1 y 63 caracteres, y no puede
coincidir con un dominio existente. Si no se indica `--title`, se usa el ID.

El título debe ser no vacío, no estar compuesto solo por espacios y ocupar una
sola línea. La CLI lo serializa como un valor YAML entrecomillado y prepara el
paquete en una ubicación temporal: si una plantilla falla, no queda un dominio
parcial.

El `domain.yml` inicial declara un alcance contextual, estado `active`, áreas
vacías y `routing.rules: []`. El agente o una persona completa propósito,
límites, vocabulario, fuentes aceptadas y áreas antes de registrar conocimiento
allí. Las reglas del `AGENTS.md` de dominio pueden restringir el contexto, pero
no relajar las reglas maestras de la vault ni autorizar operaciones persistentes.

## `check`

```sh
./scripts/vault.sh check --vault /ruta/a/vault
```

No modifica contenido. Verifica el `AGENTS.md` maestro, los directorios
obligatorios y, para cada dominio, `domain.yml`, `AGENTS.md`, `INDEX.md`,
`records/`, `resources/`, la coherencia entre el ID y el nombre de directorio,
el título, el estado `active` o `archived`, y el baseline de routing.

El baseline solo acepta `routing.rules: []`. No existe un ejecutor de routing
automático en esta versión. Una futura extensión debe modificar conjuntamente
el contrato, las dos CLI y sus pruebas; solo podrá usar metadata explícita y
deberá registrar cada movimiento en `_indexes/action-log.md`.

`check` también exige que los índices, el log de acciones y las plantillas
canónicas sean archivos locales, no enlaces simbólicos. Examina todas las
entradas de `20_domains/`, incluidas las ocultas; rechaza archivos, enlaces y
directorios que no sean paquetes válidos. En cada dominio valida `format: 1`, `id`,
`title`, `status`, `scope`, `areas` y el baseline de routing. Una vault de
formato `3` con un `INDEX.md` en raíz no es canónica: el índice legado debe
permanecer archivado en `40_archive/`.

## `migration-plan`

```sh
./scripts/vault.sh migration-plan --vault /ruta/a/vault
```

Inicializa el layout que falte e inventaría archivos `records/*.md` de una
vault heredada. Por cada uno crea, si falta, una propuesta en
`00_inbox/decisions-pending/`. No mueve registros, no interpreta su significado
y no asigna dominios. Primero valida todos los conflictos y publica las nuevas
propuestas como lote; una propuesta no regular impide publicar propuestas
parciales. Las propuestas representan una decisión humana pendiente.

## `migration-apply`

```sh
./scripts/vault.sh migration-apply --vault /ruta/a/vault \
  --domain arquitectura --record 2026-10-25--decision.md
```

Mueve un solo archivo existente de `records/` al directorio `records/` de un
dominio seleccionado. `--record` debe ser exclusivamente el basename de un
archivo `.md`, sin separadores de ruta. La operación rechaza IDs inválidos,
dominios inexistentes, registros que no estén en la raíz y destinos ya
existentes. Al tener éxito conserva los bytes del registro y añade una línea
con fecha, regla, origen, destino y actor `operator` a
`_indexes/action-log.md`.

El log de acciones debe existir como archivo. Si el registro de la acción
falla después del movimiento, la operación devuelve el archivo a `records/`
y termina con error; no declara éxito sin una traza auditable.

No elimina la propuesta pendiente ni actualiza el manifiesto de versión: la
persona responsable revisa esas consecuencias y realiza las operaciones de
release o migración de formato que correspondan.

## Extender conocimiento de forma segura

Para incorporar conocimiento persistente, primero selecciona o crea el dominio
correcto de forma explícita. Lee el `AGENTS.md` maestro, el del dominio y su
índice; después crea o actualiza un registro Markdown mediante las plantillas
canónicas de `templates/records/`. Mantén el índice del dominio y conserva la
evidencia, enlaces y cadena de reemplazo.

Si ningún dominio es apropiado, crea una propuesta en
`00_inbox/decisions-pending/` o solicita decisión humana; no inventes una
clasificación por similitud. `10_areas/` puede conectar dominios y recursos con
mapas Markdown, pero no constituye un segundo tipo de paquete portable.
