---
name: ato-ai-skill-mem
description: Administra memoria Markdown curada, local y versionable para un proyecto. Úsala cuando una tarea requiera decisiones, convenciones, historial o contexto persistente; no la uses para trabajo que no dependa de memoria.
---

# Memoria Skill (ATO AI Skill)

## Propósito y límites

Este skill administra una vault de conocimiento explícito, legible por
personas y propiedad de un proyecto. La vault conserva decisiones,
convenciones, historial y contexto estable; no captura conversaciones, no
infiere aprendizajes para persistirlos y no es un segundo cerebro.

El repositorio contiene también `ato-mem`, un CLI técnico de bajo nivel para
inspección documental y retrieval léxico reproducible. Sus cinco primitivas
son `check`, `find`, `relate`, `build` y `retrieve`; todas son de solo lectura
y el corpus de retrieval es transitorio. El CLI no es una capa de razonamiento
ni una implementación RAG.

El futuro cerebro que consuma esta memoria vivirá fuera de este módulo. Podrá
usar resultados con citas, provenance y relaciones para ensamblar contexto,
razonar o generar respuestas, pero no recibe autoridad implícita para
modificar la vault.

No actives RAG operativo, embeddings, bases vectoriales, búsqueda semántica,
clasificación por confianza, aprendizaje adaptativo, ejecución en segundo
plano, sincronización automática ni fusión de vaults. `99_runtime/rag/` es una
reserva técnica opcional; su existencia no autoriza a crear ni consumir
índices persistentes.

Usa español para la conversación, documentación y diagnósticos dirigidos a
personas. Conserva en inglés los identificadores, rutas, comandos y valores de
contrato consumidos por herramientas.

## Activación y autoridad

Activa esta skill solo cuando la tarea necesite una decisión, convención,
restricción, lección aprendida o contexto duradero del proyecto. La activación
habilita diagnóstico, lectura selectiva y propuestas; nunca autoriza escritura.

Una persona debe pedir de forma expresa y acotada cada creación, actualización,
retiro, reemplazo, movimiento, archivo, exportación o cambio estructural.

| Clase | Acción permitida | Autoridad |
| --- | --- | --- |
| Diagnóstico | Resolver fuente o consumidor y comprobar versión, formato y modo. | Activación contextual. |
| Lectura selectiva | Consultar solo las reglas y el contexto pertinente. | Activación contextual. |
| Propuesta | Recomendar un registro, dominio o migración sin escribir. | Activación contextual. |
| Cambio persistente | Escribir, mover, retirar, archivar, exportar o cambiar estructura. | Petición humana explícita. |

## Diagnóstico y lectura

Primero identifica el proyecto propietario y el tipo de vault. Una instancia
consumidora usa `mem/vault/`; el repositorio canónico usa `vault/` con
`vault_kind: source`. No uses la vault fuente como destino de un consumidor ni
compartas registros entre proyectos.

Al activar, ejecuta una sola vez `scripts/bootstrap.sh --status` para un
consumidor o `scripts/bootstrap.sh --source-status` para la fuente. Comunica
fuente, versiones, formatos, compatibilidad y modo recomendado. Usa los
equivalentes PowerShell cuando corresponda. Lee directamente `VERSION`,
`VAULT_FORMAT` o el manifiesto solo si el diagnóstico no está disponible.

Después del diagnóstico, lee únicamente la composición necesaria: `AGENTS.md`
maestro, `_indexes/INDEX.md`, mapas relevantes, metadata de dominios y el
`AGENTS.md`, `INDEX.md` y registros del dominio pertinente. No cargues todos
los registros por defecto.

Si el formato es incompatible, el manifiesto es ambiguo o la propiedad no
está autorizada, detén la operación de memoria sin modificar datos. No
interpretes una vault incompatible ni adivines otra ruta.

Los modos de bootstrap son explícitos:

- `--init`: crea una vault ausente y falla si ya existe.
- `--status` / `--source-status`: diagnostica sin mutar.
- `--contextualize`: muestra inventario y wizard sin crear estado persistente.

La contextualización acuerda propósito, audiencia, límites, tipos de datos,
evidencia, ciclo de vida y trazabilidad antes de solicitar una escritura.

## Operaciones y autoridad canónica

`scripts/vault.sh` y `scripts/vault.ps1` son la autoridad para layout,
migraciones, enlaces simbólicos y compatibilidad estructural. Consulta
[references/vault-operations.md](references/vault-operations.md) para sus
comandos, efectos y fallos.

Todas las herramientas de soporte están confinadas por rol: `source` resuelve
solo `SOURCE_ROOT/vault/` y `consumer` solo `PROJECT_PATH/mem/vault/`. No se
aceptan rutas de vault arbitrarias, `--vault`, `-Vault` ni symlinks en las
raíces autorizadas. La regla técnica completa está en
[references/runtime-boundary.md](references/runtime-boundary.md).

El CLI Python complementa esos scripts, pero no los reemplaza ni los invoca.
Consulta [references/python-cli.md](references/python-cli.md) para sus cinco
comandos, formatos, límites y códigos. Consulta
[references/instance-contract.md](references/instance-contract.md) para el
layout de la vault y la reserva opcional `99_runtime/rag/`.

`check` de cualquiera de las interfaces no modifica contenido. Las
operaciones estructurales requieren la operación explícita correspondiente;
después de una mutación autorizada se ejecuta `check` y se comunica el
resultado.

La supervisión revisa reglas, índices, metadata, enlaces y duplicación de
instrucciones, pero distingue siempre entre validación, recomendación y
mutación. No corrige una vault automáticamente.

## Precedencia local y persistencia

La precedencia es:

1. este `SKILL.md`;
2. `vault/AGENTS.md`;
3. `20_domains/<id>/AGENTS.md`;
4. operación explícita de la persona.

Las reglas locales pueden aportar vocabulario, fuentes y restricciones, pero
no pueden ampliar autoridad, habilitar routing autónomo, inferencia
persistente, sobrescritura o movimientos no auditables. El baseline de
`domain.yml` mantiene `routing.rules: []` y no existe `auto_apply`.

Los registros nuevos usan `templates/records/`, nombre
`YYYY-MM-DD--slug.md`, front matter con evidencia disponible y una entrada en
el `INDEX.md` del dominio. Los reemplazos conservan el antecedente histórico,
marcan su estado y mantienen `supersedes`/`superseded_by`. Si no hay dominio
inequívoco, prepara una propuesta en `00_inbox/decisions-pending/`.

## Versionado e integración

`VERSION` declara la versión del skill y `VAULT_FORMAT` el formato de datos;
son dimensiones independientes. La política editorial es:

- `major`: cambio público no retrocompatible;
- `minor`: capacidad pública retrocompatible;
- `patch`: corrección, documentación, pruebas, CI, refactor interno o ajuste
  operativo sin cambio de compatibilidad.

La clasificación SemVer se decide en el gate de integración sobre el diff
final que va a entrar en `master`, comparado con el último release. Una feature
o rama no fija por sí sola `major`, `minor` o `patch`; varias features pueden
desarrollarse en paralelo y cada merge se clasifica con su alcance efectivo.
El gate actualiza `VERSION`, regenera los artefactos y vuelve a validar antes
de crear el tag correspondiente.

Un release requiere `master`, checkout limpio y el tag `v<VERSION>` en el
commit de release. El bootstrap no crea tags ni commits. La actualización del
manifiesto fuente es una operación posterior y explícita.

`--integrate-codex` crea un adaptador consumidor separado y no modifica el
`AGENTS.md` del proyecto. Para integración manual, consulta
[references/agents-integration.md](references/agents-integration.md). Los
adaptadores fuente y consumidor fijan su propia ruta y no comparten memoria.

Para modificar una integración o su empaquetado, consulta también
[references/integration-alignment.md](references/integration-alignment.md) y
[references/capability-contract.md](references/capability-contract.md). Para
proponer o aplicar cambios controlados, consulta
[references/change-control-contract.md](references/change-control-contract.md).
Para preparar un candidato de release, consulta
[references/release-readiness.md](references/release-readiness.md).
La
integración de Microsoft 365 Copilot es una proyección subordinada y no una
segunda implementación del skill.

El roadmap de evolución hacia retrieval semántico y una capa RAG externa está
en [references/retrieval-roadmap.md](references/retrieval-roadmap.md). No se
implementa esa capa dentro de este skill.
