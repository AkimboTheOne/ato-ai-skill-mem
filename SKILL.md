---
name: ato-ai-skill-mem
description: Administra memoria Markdown curada, local y versionable para un proyecto. Úsala cuando una tarea requiera decisiones, convenciones, historial o contexto persistente; no la uses para trabajo que no dependa de memoria.
---

# Memoria Skill (ATO AI Skill)

## Propósito y límites

Este skill administra una vault de conocimiento explícito y legible por
personas. Una vault es almacenamiento persistente y modular: los paquetes
portables viven en `20_domains/`. No captura conversaciones, no infiere
aprendizajes para persistirlos y no es un segundo cerebro.

Usa español para la conversación, la documentación y los diagnósticos para
personas. Conserva en inglés los identificadores, rutas, comandos y valores
de contrato consumidos por herramientas. Un proyecto consumidor puede
documentar otro idioma de trabajo en sus instrucciones locales.

No incorpores RAG, bases vectoriales, búsqueda semántica, clasificación por
confianza, aprendizaje adaptativo, ejecución en segundo plano, sincronización
automática ni fusión de vaults.

## Activación y autoridad

Activa esta skill de forma contextual cuando la tarea necesite una decisión
previa, una convención, una restricción, una lección aprendida o contexto
duradero del proyecto. No la actives para trabajo ordinario que pueda
resolverse sin memoria persistente.

La activación habilita diagnóstico y lectura; nunca implica una autorización
para persistir datos. Una persona debe pedir de forma expresa y acotada cada
creación, actualización, retiro, reemplazo, movimiento, archivo, exportación
o cambio estructural. Una propuesta no persistente no equivale a esa petición.

Sigue las cuatro clases de operación y no saltes de una a otra:

| Clase | Acción permitida | Autoridad |
| --- | --- | --- |
| Diagnóstico | Resolver fuente o consumidor y comprobar versión, formato y modo. | Activación contextual. |
| Lectura selectiva | Consultar solo la guía, índice, dominio y registros necesarios. | Activación contextual y modo compatible. |
| Propuesta | Recomendar un registro, dominio o migración sin cambiar archivos. | Activación contextual. |
| Cambio persistente | Escribir, mover, retirar, archivar, exportar o cambiar estructura. | Petición humana explícita y acotada. |

## Resolver el contexto y operar

Primero identifica el proyecto propietario y el tipo de vault. Una instancia
consumidora usa `mem/vault/` dentro del proyecto anfitrión; el repositorio
canónico usa su propio `vault/` con `vault_kind: source`. La ruta del agente o
skill invocador no determina dónde se guarda la memoria. No uses la vault
fuente como destino de un consumidor, no crees vaults privados junto a un
agente y no compartas registros entre proyectos.

Las instrucciones de un agente o de una skill anfitriona pueden solicitar esta
skill y declarar el proyecto objetivo, pero no transfieren propiedad ni
autoridad de escritura. Si el runtime no puede resolver ambas cosas de forma
explícita, informa la limitación y no adivines una vault alternativa.

Al activar, ejecuta una sola vez `--status` para consumidores o
`--source-status` para la fuente y comunica fuente, versiones, formatos,
compatibilidad y modo recomendado. Estos comandos son el diagnóstico
autoritativo de solo lectura. Lee directamente `VERSION`, `VAULT_FORMAT` y el
manifiesto solo si el comando correspondiente no está disponible.

Después del diagnóstico, identifica la composición mínima de la vault sin
cargar todos sus registros: confirma los directorios canónicos, lee el
`AGENTS.md` maestro y `_indexes/INDEX.md`, observa los mapas disponibles y
recorre la metadata de cada `20_domains/<id>/domain.yml` (`id`, `title`,
`status`, `scope`, `areas` y `routing`). Comunica el número y estado de los
dominios y cualquier inconsistencia visible. El `AGENTS.md` y el `INDEX.md` de
un dominio se leen completos solo cuando ese dominio sea pertinente para la
tarea.

Elige un único modo en este orden:

1. **Instalación pendiente:** no existe la vault. Recomienda instalarla; no la
   crea sin petición humana explícita.
2. **Planificación de migración:** el formato es incompatible. No interpreta
   datos como compatibles ni escribe; explica el impacto y espera confirmación.
3. **Vault más nuevo:** la versión registrada es mayor. No rebaja el
   manifiesto; recomienda la fuente publicada correspondiente.
4. **Desarrollo sin promoción:** la fuente no está `release-aligned`. Puede
   leer datos compatibles, pero no recomienda ni ejecuta actualizaciones.
5. **Operación compatible:** puede consultar registros y proponer cambios.

Ante formato incompatible, manifiesto ambiguo o propiedad no autorizada,
detén la operación de memoria sin modificar datos. No conviertas un diagnóstico
en instalación, migración o reparación automática.

Para una lectura compatible, sigue este orden: `AGENTS.md` maestro,
`_indexes/INDEX.md`, mapas o áreas relevantes, y únicamente el `AGENTS.md`,
`INDEX.md` y registros del dominio pertinente. No cargues todos los registros
por defecto. Explica qué información de memoria fue material para la decisión.

## Inicialización y contextualización guiada

El bootstrap conserva su comportamiento histórico sin flags, pero informa el
estado de inicialización y un inventario estructural de la vault. Las
transiciones explícitas disponibles para consumidores son:

- `--init` (`-Init`): crea únicamente una vault ausente; falla si ya existe.
- `--status` (`-Status`): inspecciona release, compatibilidad y composición sin
  modificar archivos.
- `--contextualize` (`-Contextualize`): muestra el inventario y el plan guiado
  sin crear scaffold, manifiesto ni registros.

El inventario expone `vault.initialization.state` (`new` o `existing`),
`vault.context.state` (`needs-definition`, `needs-review`,
`structurally-ready` o `blocked`) y `vault.context.next_step`. También cuenta
`AGENTS.md`, índices, dominios, metadata, registros, propuestas pendientes y
recursos. Estos valores son observaciones transitorias; no constituyen un
estado persistente de contextualización.

Cuando la vault sea nueva, conduce cuatro iteraciones antes de proponer
memoria persistente: definir propósito y audiencia; leer las reglas maestras,
índices, mapas y metadata; acordar la gestión de datos; y validar con `check`
antes de solicitar autorización concreta. Cuando sea existente, conserva la
misma secuencia, pero lee primero el contexto declarado y solo los dominios
pertinentes. No resumas ni clasifiques semánticamente desde el bootstrap.

La gestión de datos requiere tipos de registros explícitos, evidencia,
índices mantenidos, ciclo de vida y trazabilidad de movimientos. Las propuestas
no autorizan escrituras; crear, actualizar, mover, archivar o cambiar la
estructura continúa requiriendo una petición humana explícita.

## Supervisión de la vault

La supervisión es una revisión de solo lectura que se activa cuando la persona
solicita auditar, supervisar, optimizar o revisar la vault, cuando una
operación estructural termina, o cuando el diagnóstico señala una
inconsistencia. Ejecuta `scripts/vault.sh check` o `scripts/vault.ps1 check` y
revisa todos los `AGENTS.md` e `INDEX.md` de los dominios para detectar reglas
que contradigan la precedencia, dominios ausentes de los índices, registros no
enlazados, metadata incoherente, referencias obsoletas y duplicación de
instrucciones que aumente el contexto.

Distingue siempre entre validación, recomendación y mutación. La supervisión
puede señalar incumplimientos y proponer una reducción de contexto, pero no
crea propuestas, actualiza índices, corrige agentes, mueve registros, activa
routing ni modifica la vault sin una orden humana explícita y acotada.

## Cambios persistentes

Antes de cambiar la vault, confirma que la petición humana identifica el
resultado y el alcance. Conserva contenido, evidencia y enlaces; no
sobrescribas ni borres datos para resolver conflictos. Un reemplazo crea un
sucesor, marca el antecedente `retired`, mantiene `superseded_by`/
`supersedes` y conserva la referencia histórica en el índice.

Los registros nuevos usan una plantilla de `templates/records/`, un nombre
`YYYY-MM-DD--slug.md`, front matter con evidencia disponible y una entrada de
una línea en el `INDEX.md` del dominio. Si no existe un dominio inequívoco,
prepara una propuesta en `00_inbox/decisions-pending/`; no clasifiques por
similitud semántica.

La interfaz canónica es `scripts/vault.sh` y `scripts/vault.ps1`. Consulta
[references/vault-operations.md](references/vault-operations.md) para los
comandos, sus efectos y fallos. `init-layout`, `create-domain`,
`migration-plan` y `migration-apply` requieren petición humana expresa;
`check` no modifica contenido. Tras una operación estructural solicitada,
ejecuta `check` y comunica el resultado.

El paquete Python `ato-ai-mem` y el comando `ato-mem` son una interfaz
complementaria de lectura para vaults formato `3`. Sus comandos `check`,
`find`, `relate`, `build` y `retrieve` no reemplazan los scripts canónicos,
no escriben la vault, no crean cachés ni índices y no acceden a la red.
`ato-mem check` añade una auditoría documental de front matter, relaciones e
índices; `build` y `retrieve` construyen y consultan un corpus léxico
transitorio con provenance. No incluyen embeddings, generación RAG ni
inferencias persistentes. La interfaz y sus códigos de salida están
documentados en [references/python-cli.md](references/python-cli.md); el
roadmap gobernado está en [references/retrieval-roadmap.md](references/retrieval-roadmap.md).

La migración de formato `2` a `3` es explícita y en dos fases mediante el
bootstrap: preparar propuestas y layout, después finalizar solo cuando no haya
contenido pendiente en `records/`. La finalización archiva el índice heredado,
actualiza el manifiesto solo al final y conserva el estado anterior ante un
conflicto. No la ejecutes al diagnosticar o leer.

## Precedencia local

La precedencia es: reglas globales de este skill → `vault/AGENTS.md` →
`20_domains/<id>/AGENTS.md` → operación explícita de la persona. Las reglas
locales pueden aportar vocabulario, fuentes aceptadas y restricciones; nunca
pueden ampliar autoridad ni habilitar inferencia persistente, sincronización,
routing autónomo, sobrescritura o movimientos no auditables.

El baseline de `domain.yml` exige `routing.rules: []`. No existe
`auto_apply`. Cualquier extensión futura requiere cambio explícito de contrato,
implementación equivalente en Bash y PowerShell, pruebas de trazabilidad y
reglas basadas solo en metadata declarada.

## Versionado, release e integración

`VERSION` declara la versión SemVer y `VAULT_FORMAT` el formato de datos. El
manifiesto visible registra versión, revisión, tag, fechas, `vault_format` y
`vault_kind`; no contiene secretos ni estado inferido. Los formatos `1` y `2`
son heredados; detectar uno incompatible produce un diagnóstico y una
propuesta, nunca una migración automática.

### Política editorial SemVer

La línea editorial interpreta `VERSION` con tres niveles:

- `X` (`major`): cambio público no retrocompatible en el contrato del skill,
  la CLI, la integración o la estructura que consume una vault.
- `Y` (`minor`): nueva capacidad pública por extensión, retrocompatible con
  los flujos y contratos existentes.
- `Z` (`patch`): corrección, documentación, pruebas, CI, refactor interno o
  ajuste operativo sin nueva capacidad pública ni cambio de compatibilidad.

Esta convención se aplica también durante `0.x` como política editorial del
proyecto; `1.0.0` marcará la primera versión con contrato estable declarado.
`VAULT_FORMAT` es una dimensión independiente: un cambio incompatible de
formato requiere su propia decisión de migración y no se infiere solo desde
el número de `VERSION`.

Una distribución válida requiere el tag `v<VERSION>` en `master`. La fuente
puede leerse durante desarrollo si los datos son compatibles, pero su marcador
solo se actualiza con `--update-source-vault` desde un checkout limpio y
release-aligned; la operación no crea tags ni commits.

La publicación tiene dos puntos de control deliberadamente separados: primero
el tag inmutable `v<VERSION>` sobre el commit de release en `master`; después,
el commit documental que actualiza el manifiesto mediante
`--update-source-vault`. Como el segundo commit avanza `master` después del
tag, `source.state: not-release-aligned` es una observación esperada del
checkout posterior y no invalida el release. La alineación editorial final se
comprueba con el tag remoto intacto, `master` local igual a `origin/master`, y
`vault.state: aligned` con `skill_version`, `source_revision` y `source_tag`
coherentes. No fuerces ni muevas un tag público para ocultar esa diferencia.

`--integrate-codex` crea un adaptador consumidor separado y no modifica el
`AGENTS.md` del proyecto. Para una integración manual, consulta
[references/agents-integration.md](references/agents-integration.md). El
contrato de layout está en [references/instance-contract.md](references/instance-contract.md).

El repositorio canónico expone `.agents/skills/ato-ai-source-mem/` como punto
de entrada para la vault fuente. Los adaptadores fuente y consumidor fijan su
propia ruta y remiten a este contrato para modos y autoridad; ninguno amplía
las capacidades del skill.
