---
name: ato-ai-skill-mem
description: Administra memoria curada, local y versionable para un proyecto y sus agentes. Úsala cuando una tarea requiera consultar, registrar, actualizar, retirar o reemplazar decisiones, convenciones, aprendizajes o contexto de proyecto.
---

# Memoria Skill (ATO AI Skill)

## Propósito

Este skill mantiene una memoria explícita y legible por personas en
`vault/`. Es un almacenamiento persistente y modular: `20_domains/` contiene
paquetes contextuales portables con sus propios registros y reglas locales.

El skill administra conocimiento curado. No captura automáticamente
conversaciones, no infiere aprendizajes para persistirlos y no funciona como un
segundo cerebro.

## Idioma

Usa español para la conversación, el razonamiento expuesto, la documentación,
las plantillas y los diagnósticos para personas. Conserva en inglés los
identificadores de programación, nombres de archivos, comandos, claves y
valores de contratos consumidos por herramientas, y términos técnicos
establecidos. Un proyecto consumidor puede definir otro idioma de trabajo en
sus instrucciones locales.

## Activación

Actívalo cuando una petición requiera historia o memoria del proyecto, por
ejemplo decisiones previas, convenciones, restricciones, lecciones aprendidas
o contexto activo. También se activa ante una instrucción explícita de guardar,
actualizar, retirar o reemplazar memoria.

No lo actives para tareas que no dependen de memoria persistente.

## Contextos de invocación e integración

La skill puede ser invocada desde tres contextos. El contexto cambia quién
presenta la instrucción; no cambia la propiedad ni la ruta de la memoria:

| Contexto | Uso | Soporte actual |
| --- | --- | --- |
| Skill en proyecto | Una skill local del proyecto consulta la memoria del proyecto. | Soportado por la instalación `--target`; Codex puede añadir el adaptador explícito. |
| Skill en agente | Las instrucciones de un agente delegan la consulta o escritura solicitada en esta skill. | Patrón documental: el agente anfitrión debe referenciar la skill y declarar el proyecto objetivo. |
| Skill en skill | Una skill compuesta declara esta skill como dependencia para tareas de memoria. | Patrón documental: la skill anfitriona debe referenciar la dependencia y el proyecto propietario. |

En los tres casos, antes de operar identifica el proyecto propietario y usa
   su vault configurado. La ruta del skill invocador o del agente no
   determina por sí sola dónde guardar memoria. Para un consumidor soportado, el
   vault es `mem/vault/` dentro del proyecto anfitrión. No uses el
   `vault/` del repositorio fuente como destino de un consumidor ni crees
vaults privados junto al agente o skill. Si un repositorio que contiene
una skill necesita memoria para desarrollar ese proyecto, puede ser
consumidor por derecho propio: instala la instancia en `mem/` y conserva allí
   su `mem/vault/`, separado de cualquier vault de los proyectos que
atienda.

Las integraciones en agente o skill anfitriones deben conservar la evaluación
de carga, la lectura selectiva y la escritura explícita definidas aquí. No
copien este documento para crear una política paralela: declaren la
dependencia, cómo invocarla y cuál es el proyecto objetivo. Si el runtime no
puede resolver esa dependencia o ruta de forma explícita, informa la
limitación y no adivines otro vault.

El bootstrap implementa instalación en proyectos y un adaptador de Codex; no
instala automáticamente la skill en agentes o skills de otras plataformas.
El vault de cada consumidor puede versionarse con el repositorio de ese
proyecto. Compartir o promover conocimiento entre proyectos es una acción
separada y deliberada; no hay sincronización automática ni fusión de
vaults.

## Lectura selectiva

1. Ejecuta la evaluación de carga antes de usar o modificar memoria.
2. Lee `vault/AGENTS.md` y `_indexes/INDEX.md`.
3. Identifica el dominio relevante en `20_domains/`.
4. Abre solo su `AGENTS.md`, `INDEX.md` y registros pertinentes.
5. Explica qué información de memoria modificó la decisión si resulta material.

No cargues todos los registros por defecto.

## Evaluación de carga

Al cargar el skill, lee `VERSION`, `VAULT_FORMAT` y, si existe,
`vault/.ato-ai-skill-mem-version.yml`. Expón un diagnóstico breve y
visible con: estado de la fuente, versión fuente y registrada, formato fuente
y registrado, compatibilidad de datos y modo recomendado. Si el instalador
está disponible, `--status` aporta esos mismos datos sin escribir.

Elige un único modo aplicando estas reglas en orden de prioridad:

1. **Instalación pendiente:** el vault no existe. Recomienda instalar la
   instancia; no lo hace salvo petición humana explícita.
2. **Planificación de migración:** el formato es incompatible. No escribe ni
   interpreta registros como compatibles; explica el impacto, propone pasos y
   espera confirmación humana explícita.
3. **Vault más nuevo:** la versión registrada es mayor. No rebaja el
   manifiesto; recomienda seleccionar la fuente publicada correspondiente.
4. **Desarrollo sin promoción:** la fuente no es `release-aligned`. Puede leer
   datos compatibles, pero no recomienda ni ejecuta una actualización de
   manifiesto.
5. **Operación compatible:** el formato es compatible y el vault está
   alineado, heredado o requiere una actualización compatible. Lee y usa los
   registros normalmente; recomienda actualizar el manifiesto solo bajo las
   condiciones de versionado.

## Escritura explícita

Solo modifica `vault/` cuando una persona pida expresamente registrar,
actualizar, retirar o reemplazar memoria. Una propuesta de cambio puede
presentarse sin escribir archivos.

Al crear un registro:

1. Usa una plantilla de `templates/records/`.
2. Nómbralo `YYYY-MM-DD--slug.md` dentro de `20_domains/<id>/records/`.
3. Completa el front matter y la evidencia disponible.
4. Añade un enlace y un resumen de una línea al `INDEX.md` del dominio.

Al reemplazar un registro:

1. Crea el registro sucesor.
2. Cambia el anterior a `status: retired`.
3. Añade `superseded_by` en el anterior y `supersedes` en el nuevo.
4. Sustituye el enlace activo en el `INDEX.md` del dominio; conserva la
   referencia histórica en la sección de retirados.

No borres un registro solo porque haya quedado obsoleto.

## Métodos de operación de la vault

La interfaz canónica está en `scripts/vault.sh` y `scripts/vault.ps1`. Sus
interfaces son equivalentes y requieren una vault existente: usa
`--vault <ruta>` en Bash o `-Vault <ruta>` en PowerShell. Consulta
[references/vault-operations.md](references/vault-operations.md) antes de
invocar una operación de estructura o migración.

| Método | Cuándo usarlo | Efecto y garantía |
| --- | --- | --- |
| `init-layout` | Crear o completar un scaffold vacío por petición explícita. | Crea solo directorios, índices y plantillas que faltan; no sobrescribe. |
| `create-domain <id>` | Existe una decisión explícita de abrir un contexto portable. | Crea `20_domains/<id>/` con metadata, instrucciones, índice, registros y recursos; rechaza IDs o rutas en conflicto. |
| `check` | Antes de operar, tras crear un dominio o en revisión. | Solo lee y valida la estructura, metadata y baseline de routing. |
| `migration-plan` | Hay registros heredados en `vault/records/`. | Crea propuestas individuales en `00_inbox/decisions-pending/`; no mueve ni clasifica. |
| `migration-apply --domain <id> --record <archivo>` | Una persona seleccionó expresamente el dominio destino de un registro. | Mueve un único archivo `.md` de `records/`, sin rutas ni sobrescrituras; registra la acción y revierte el movimiento si no puede registrar el log. |

`init-layout` y `create-domain` modifican estructura; `migration-plan` y
`migration-apply` modifican el estado indicado. Nunca los invoques durante
lectura, `--status` o evaluación de carga sin una petición humana explícita.
Después de cualquier operación estructural solicitada, ejecuta `check` y
comunica el resultado.

Para una vault de formato `2`, el bootstrap ofrece una migración explícita en
dos fases: `--migrate-vault-format` prepara el layout y las propuestas sin
alterar el manifiesto; `--migrate-vault-format --finalize` exige que no queden
registros raíz, archiva el `INDEX.md` heredado en `40_archive/` y recién
entonces escribe formato `3`. No finalices por inferencia ni elimines el índice
heredado; cualquier conflicto debe conservar el estado anterior.

Para extender conocimiento, no concluyas un dominio por similitud semántica.
Lee el `AGENTS.md` maestro, selecciona explícitamente un dominio existente o
pide crear uno, y luego sigue su `AGENTS.md`, `INDEX.md` y las plantillas de
registros. Si el destino no está claro, prepara una propuesta en
`00_inbox/decisions-pending/` en lugar de mover o persistir contenido. Un área
en `10_areas/` puede enlazar conocimiento transversal, pero no reemplaza el
dominio como unidad portable.

El baseline de `domain.yml` exige `routing.rules: []`. No hay `auto_apply` ni
routing automático implementado. Para incorporar esa capacidad en el futuro se
requiere un cambio explícito de contrato, implementación equivalente en Bash y
PowerShell, pruebas de trazabilidad y una regla basada exclusivamente en
metadata declarada; no se habilitan similitud, confianza ni aprendizaje.

## Restricciones

- No guardes secretos, credenciales, tokens, datos personales sensibles ni
  transcripciones completas de conversaciones.
- No escribas de manera automática al cerrar una tarea o sesión.
- No introduzcas bases vectoriales, RAG, servicios externos, sincronización
  automática entre proyectos ni ejecución en segundo plano.
- No sobrescribas contenido existente durante una actualización de la
  instalación.

## Versionado y alineación

`VERSION` declara la versión SemVer del skill y `VAULT_FORMAT` el formato
de datos que el skill sabe operar. Una versión distribuible debe corresponder
al tag Git `v<VERSION>` aplicado al commit de `master`.

`vault/.ato-ai-skill-mem-version.yml` es un manifiesto visible, separado
de los registros de memoria: guarda la versión, revisión, tag y fechas de la
última inicialización o actualización explícita, incluido su
`vault_format` y `vault_kind`. `vault_kind: consumer` identifica
la memoria de una instancia; `vault_kind: source` identifica la memoria
documental del repositorio canónico. No contiene secretos ni estado inferido.
Si el manifiesto no existe o no incluye esos campos, el vault se trata
como formato heredado `1` y tipo `consumer`.

La revisión y el tag son evidencia auditable del origen; la compatibilidad y
el modo de operación se deciden por el formato y la versión SemVer. Así, una
revisión distinta no fuerza por sí sola una migración ni una actualización.

El formato `1` y el formato `2` son heredados. Durante la etapa `0.x`, una versión
menor puede introducir un nuevo formato de datos si documenta los pasos de
migración y exige confirmación humana explícita; este cambio introduce el
formato `2` en `0.2.0` y el formato modular `3` en `0.3.0`. Una vez alcanzada `1.0.0`, los cambios incompatibles
de formato requieren una nueva versión mayor. Detectar un formato incompatible
debe producir un diagnóstico y propuesta, no una migración automática.

Usa `scripts/bootstrap.sh --target <project> --status` (o el equivalente de
PowerShell) para inspeccionar la alineación sin modificar datos. Si el
vault requiere actualizar su marcador, usa `--update-vault`; esta
rutina requiere una instancia existente, una fuente `release-aligned` y
preserva contenido existente. Una fuente que no esté en `master` y taggeada se
informa como `not-release-aligned`; no debe presentarse como una distribución
publicada ni usarse para actualizar una marca existente.

Un proyecto consumidor puede exponer el skill a Codex mediante un adaptador
local y explícito. `--integrate-codex` crea
`.ato-ai-skill-mem.yml` y `.agents/skills/ato-ai-project-mem/SKILL.md`; este
último es un archivo local que delega en `mem/SKILL.md` y fija
`mem/vault/` como su único vault. No enlaza el adaptador directamente
a la fuente ni modifica `AGENTS.md`. La configuración declara rutas, no
autoriza escrituras de memoria. El formato actual reserva integraciones para
otros agentes, pero solo implementa `codex`.

El repositorio canónico conserva su propio `vault/` sin enlaces simbólicos
ni instalación recursiva. Su marcador referencia el último release que lo
validó, por lo que un checkout de desarrollo posterior puede leerse si es
compatible, pero opera en desarrollo sin promoción. Usa `--source-status` para
consultarlo y `--update-source-vault` solo desde un checkout limpio en
`master` cuyo `HEAD` sea `v<VERSION>`; esta operación escribe únicamente el
marcador y requiere una revisión y commit humano posterior.

El `AGENTS.md` de la vault establece reglas no anulables; los de dominio pueden
ampliar o acotar contexto, pero no habilitan inferencia adaptativa ni efectos
no auditables. Consulta [references/instance-contract.md](references/instance-contract.md)
para el formato canónico, [references/agents-integration.md](references/agents-integration.md)
para la integración manual en proyectos consumidores y [templates/](templates/)
para las plantillas.
