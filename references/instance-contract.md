# Contrato de instancia

## Propiedad

`mem/SKILL.md`, `mem/VERSION`, `mem/VAULT_FORMAT`, `mem/references/`,
`mem/templates/` y `mem/scripts/` son enlaces simbólicos al skill canónico.
`mem/vault/` pertenece al proyecto consumidor y debe ser una carpeta real,
versionable y no sobrescribible por el bootstrap.

## Estructura del vault

```text
vault/
├── AGENTS.md
├── 00_inbox/decisions-pending/
├── 10_areas/
├── 20_domains/<domain-id>/
│   ├── AGENTS.md
│   ├── domain.yml
│   ├── INDEX.md
│   ├── records/
│   └── resources/
├── 30_resources/
├── 40_archive/
├── 50_daily/
├── 60_exports/
├── 99_runtime/
│   └── rag/                  # extensión técnica opcional
├── _indexes/
├── _maps/
└── _templates/
```

`99_runtime/rag/` es una extensión técnica opcional del formato `3`. No es
un dominio portable ni contiene registros humanos, `AGENTS.md` o `INDEX.md`.
Cuando existe, su estructura local es:

```text
99_runtime/rag/
├── manifest.yml
└── indexes/<index-id>/data/
```

`manifest.yml` será legible, versionable y conservará provenance cuando exista
un productor de índices. `indexes/*/data/` contendrá artefactos derivados y
reconstruibles, por lo que debe ignorarse en Git. La ausencia de
`99_runtime` mantiene la compatibilidad con vaults existentes de formato `3`;
si aparece, `check` exige que `99_runtime`, `rag`, los índices, sus
directorios `data/` y un `manifest.yml` presente sean rutas locales y no
enlaces simbólicos.

El esquema semántico del manifiesto queda pendiente hasta que exista una
operación explícita que genere índices persistentes. Esta reserva no concede
autoridad para modificar la memoria documental.

## Alineación de versión

`VERSION` en la raíz canónica es la versión SemVer declarada y
`VAULT_FORMAT` es el entero que identifica el formato de datos soportado.
Un release válido debe estar en `master` y tener el tag Git exacto
`v<VERSION>` en el mismo commit. El bootstrap no consulta la red: valida solo
el checkout local.

`.ato-ai-skill-mem-version.yml` pertenece al vault y registra la última
versión, revisión y `vault_format` del skill que lo inicializó o actualizó
de forma explícita. Es metadata operativa, no un registro de memoria. El
bootstrap lo crea si no existe; `--update-vault` solo lo renueva en una
instancia existente desde una fuente `release-aligned`, sin tocar el índice ni
los registros.

El campo `vault_kind` distingue la propiedad del vault: `consumer`
para `mem/vault/` y `source` para `vault/` del repositorio canónico.
Los manifiestos anteriores sin ese campo se interpretan como `consumer`. Un
bootstrap de consumidor rechaza un manifiesto de fuente y la raíz canónica no
puede utilizarse como `--target`.

El bootstrap expone además un estado transitorio de inicialización y
contextualización. `vault.initialization.state` distingue `new` de `existing`;
`vault.context.state` puede ser `needs-definition`, `needs-review`,
`structurally-ready` o `blocked`. El estado no se escribe en el manifiesto y
no sustituye la revisión humana del contexto.

`--init` solo permite la transición de una vault ausente a un scaffold. La
ejecución sin flag conserva compatibilidad y completa el scaffold idempotente.
`--contextualize` y `--status` son de solo lectura. Ambos runtimes deben
producir las mismas claves y decisiones.

El vault de fuente se consulta con `--source-status` y se actualiza con
`--update-source-vault` (o sus equivalentes PowerShell). La migración explícita
usa `--migrate-workspace-to-vault` o `--migrate-source-workspace-to-vault`.
La operación de actualización exige `master`, checkout limpio y `HEAD` en
`v<VERSION>`; conserva
índice y registros, escribe solo el manifiesto y no crea commits ni tags. Su
referencia puede apuntar al último release aunque el checkout posterior esté
en desarrollo. El commit documental posterior puede dejar `source.state:
not-release-aligned` porque `master` avanza después del tag; eso no invalida el
release. La comprobación final conserva el tag sobre el commit de release,
verifica que `master` local y `origin/master` coincidan y exige
`vault.state: aligned`. Nunca se debe forzar o mover un tag público para
absorber el commit documental.

## Integración de agentes

Un consumidor puede declarar una integración local en
`.ato-ai-skill-mem.yml`. El formato `3` fija `vault.path` en
`mem/vault` y admite únicamente `integrations.codex.adapter_path` con el
valor `.agents/skills/ato-ai-project-mem`. El namespace `integrations` queda
reservado para adaptadores futuros, pero valores adicionales se rechazan hasta
que exista un contrato versionado para ellos.

`--integrate-codex` crea o valida el archivo y el adaptador de Codex. El
adaptador contiene un `SKILL.md` regular que dirige al agente a `mem/SKILL.md`;
no es un enlace hacia la fuente y no debe acceder al vault de fuente. Si
la configuración, ruta o contenido preexistente difiere, el bootstrap falla
sin reemplazarlo ni modificar `AGENTS.md`.

Los formatos `1` y `2` son heredados. El formato `3` añade el scaffold
modular y dominios portables. La migración crea propuestas en
`00_inbox/decisions-pending/`; no asigna registros a un dominio por
similitud semántica.

Una instancia con `vault_format: 2` se migra mediante
`--migrate-vault-format`. La preparación conserva el manifiesto en formato
`2` y crea las propuestas necesarias. Tras mover los registros raíz de forma
explícita, `--migrate-vault-format --finalize` archiva el `INDEX.md` heredado
en `40_archive/legacy-root-INDEX.md`, sin sobrescribir, y escribe el
manifiesto de formato `3`. La finalización exige que el layout ya esté
preparado y que `records/` esté vacío; si hay archivos, enlaces o un conflicto,
falla sin actualizar el manifiesto, crear scaffold ni mover el índice.

`vault/AGENTS.md` y `_indexes/INDEX.md` son el punto de entrada de lectura.
La activación obtiene además una composición ligera desde cada `domain.yml`,
sin cargar todos los registros. Cada dominio mantiene su propio `AGENTS.md` e
`INDEX.md`; el primero define contexto local y el segundo navegación. Los
dominios son la única unidad portable y sus reglas no pueden relajar las
reglas maestras.
Una vault de formato `3` no conserva `INDEX.md` en la raíz.

## Dominio portable

`domain.yml` debe incluir `format`, `id`, `title`, `status`, `scope`, `areas`
y `routing`. El baseline valida exclusivamente `routing.rules: []`: la CLI no
ejecuta routing automático. Cualquier evolución debe ser determinista, basarse
en metadata explícita y quedar definida en el contrato, la CLI y las pruebas
antes de habilitarse; cada movimiento debe registrarse en
`_indexes/action-log.md`. No se admite clasificación por similitud, confianza
ni historial de decisiones.

La supervisión de calidad usa `check` y revisa, cuando se solicita o después
de una operación estructural, todos los `AGENTS.md` e `INDEX.md` de los
dominios. Es una revisión de solo lectura para detectar incoherencias,
referencias obsoletas, dominios o registros fuera de los índices y duplicación
de instrucciones. No corrige ni reorganiza contenido automáticamente.

`scripts/vault.sh` y `scripts/vault.ps1` exponen `init-layout`,
`create-domain`, `check`, `migration-plan` y `migration-apply`. La primera
operación crea propuestas para registros raíz heredados; la segunda mueve solo
un registro y dominio seleccionados explícitamente, sin sobrescribir destinos.
Si no puede registrar la acción, revierte el movimiento y falla.

## Esquema de registros

Cada archivo de `records/` debe tener este front matter:

```yaml
---
id: YYYY-MM-DD--slug
type: decision | convention | lesson | project-context
status: active | retired
created: YYYY-MM-DD
updated: YYYY-MM-DD
scope: project
author: human | agent-name
sources: []
related: []
supersedes: null
superseded_by: null
---
```

`sources` enumera evidencia o archivos locales que sustentan la entrada.
`related` usa enlaces Markdown relativos o rutas de proyecto. Los campos de
reemplazo usan enlaces Markdown relativos; son `null` salvo cuando aplica.

El cuerpo incluye, como mínimo, una afirmación o decisión, su razón/evidencia y
sus implicaciones operativas. La plantilla de cada tipo establece el orden.

## Ciclo de vida

- Un registro nuevo comienza como `active`.
- Un cambio correctivo actualiza el mismo registro y su campo `updated`.
- Un cambio que invalida la conclusión crea un sucesor y retira el anterior.
- Un registro retirado se conserva, enlaza a su sucesor y deja de aparecer como
  activo en el índice.

## Integración del agente

El bootstrap no modifica `AGENTS.md`. Para activar lectura selectiva en un
proyecto consumidor, copia el bloque canónico de
[agents-integration.md](agents-integration.md) y mantenlo como parte de las
instrucciones locales del proyecto.
