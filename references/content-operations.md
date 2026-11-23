# Operaciones de contenido

`SKILL.md` define las reglas comunes de todas las operaciones. Para crear
contenido, elige la ubicación y plantilla por su propósito; si Python no está
disponible, sigue este contrato manualmente y adquiere el mismo lock.

| Contexto | Ubicación | Plantilla recomendada |
| --- | --- | --- |
| Decisión, convención, lección o contexto | `20_domains/<id>/records/` | `templates/records/<tipo>.md` |
| Pendiente | `00_inbox/decisions-pending/` | `wiki/_templates/pending-decision.md` |
| Área | `10_areas/` | `wiki/_templates/area.md` |
| Diario | `50_daily/` | `wiki/_templates/daily.md` |
| Exportación | `60_exports/` | `wiki/_templates/export.md` |
| Recursos | `30_resources/` o `20_domains/<id>/resources/` | `wiki/_templates/resource.md` |
| Mapas | `_maps/` | `wiki/_templates/map.md` |
| Archivo | `40_archive/` | `wiki/_templates/archive.md` |

Los documentos nuevos incluyen `id`, `type`, `status`, `created`, `updated`, `author` y `sources`; las instrucciones y los índices llevan metadatos de tipo y formato. Los documentos existentes sin este esquema permanecen compatibles y no se migran automáticamente. Ejecuta `init-layout` para incorporar las plantillas ausentes en una instalación existente.

## Nombres para contenido nuevo

Elige nombres explícitos y descriptivos: minúsculas ASCII, dígitos y guiones
simples, sin espacios ni tildes. No traduzcas ni modifiques los títulos o el
contenido para cumplir el nombre. Las reglas se aplican a nombres nuevos:

| Tipo | Expresión regular | Ejemplo |
| --- | --- | --- |
| Dominio o carpeta de contenido | `^[a-z0-9]+(?:-[a-z0-9]+)*$` | `arquitectura-local` |
| Documento Markdown | `^[a-z0-9]+(?:-[a-z0-9]+)*\.md$` | `guia-de-instalacion.md` |
| Registro de dominio | `^\d{4}-\d{2}-\d{2}--[a-z0-9]+(?:-[a-z0-9]+)*\.md$` | `2026-11-18--decision-de-arquitectura.md` |
| Diario | `^\d{4}-\d{2}-\d{2}\.md$` | `2026-11-18.md` |

En los identificadores de dominio, limita la longitud a 63 caracteres. Valida
que las fechas sean reales y rechaza `con`, `prn`, `aux`, `nul`, `com1` a
`com9` y `lpt1` a `lpt9` como nombres completos de carpeta o de archivo sin
extensión: son nombres reservados en Windows. Las carpetas y archivos
estructurales, como `20_domains/`, `_indexes/`, `AGENTS.md` e `INDEX.md`,
conservan sus nombres establecidos.

La CLI valida el nombre nuevo de `create`, el destino propuesto por `plan-move`
y los identificadores de `create-domain`. Una carpeta de contenido nueva se
nombra manualmente con la misma regla. Los nombres heredados no se renombrarán
ni se rechazarán durante `check` o `read` por esta convención; para retirar un
documento se conserva su nombre al archivarlo. Esta convención no garantiza la
interpretación de enlaces: mover y retirar siguen requiriendo revisión manual.

Al encontrar un nombre heredado que dificulte el uso de la wiki, el agente
puede recomendar ajustarlo a este criterio, indicando la ruta actual, el
nombre propuesto y las referencias o efectos que requieran revisión. La
recomendación no autoriza el cambio: cualquier renombrado requiere petición
humana explícita y debe preservar contenido, enlaces e historial bajo el
lock. No renombres automáticamente ni cambies nombres estructurales.

Los registros de dominio se sitúan directamente en `records/`, sin
subcarpetas, y usan además el front matter de su plantilla. No
publiques marcadores sin completar. Los paquetes de dominio se crean con
`create-domain`; sus metadatos e instrucciones se mantienen explícitamente y
se validan con `check`.

## Flujos

- **Consultar:** indica una ruta relativa a la wiki. La lectura devuelve el contenido; una ruta inexistente, ajena o no regular falla sin cambios.
- **Crear:** indica destino y contenido preparado, usando la plantilla recomendada cuando corresponda. Revisa identidad, evidencia y enlaces. El destino debe estar ausente; para registros se añade al índice del dominio un enlace cuya etiqueta es el identificador del registro. El título completo permanece en el documento.
- **Actualizar:** indica destino y contenido completo revisado. Conserva identidad, procedencia y enlaces; para registros no cambies `id`, `status`, `created`, `author`, `sources`, `related`, `supersedes` ni `superseded_by` mediante esta operación. Un cambio de estado requiere revisar y ejecutar manualmente el ciclo de vida y su índice. Revisa el resultado y el índice pertinente.
- **Mover o retirar:** prepara `plan-move` o `plan-retire` y revisa manualmente las referencias antes de cambiar nada. El retiro conserva el documento en `40_archive/`; para un registro, conserva el historial, marca su estado y actualiza su índice y cadena de sucesión cuando corresponda. Registra cada movimiento en el log.

Los comandos `move` y `retire` se detienen sin escribir. La CLI no interpreta ni reescribe Markdown automáticamente: el operador realiza estos cambios manualmente bajo el lock después de revisar las referencias. La petición humana explícita de mover o retirar autoriza los cambios necesarios para completar esa operación.

La CLI rechaza colisiones, rutas fuera de la wiki y symlinks en las rutas utilizadas. Cada creación o actualización registra fecha, operación y ruta en `_indexes/action-log.md`. El contenido, los índices y el log forman una operación: se comprueban colisiones y cambios concurrentes antes de publicar cada archivo; si falla la publicación se intenta revertir y se informa cualquier fallo de reversión. La operación no es atómica entre varios archivos y la comprobación de cambios no excluye una escritura simultánea posterior a ella. Tras una mutación, ejecuta `check` y revisa los documentos afectados; el diagnóstico estructural no valida su contenido ni sus enlaces.

## Asistente Python

```sh
python3 scripts/content.py template --type daily
python3 scripts/content.py read --path 50_daily/2026-11-17.md
python3 scripts/content.py create --path 50_daily/2026-11-17.md --input /tmp/nota.md
python3 scripts/content.py update --path 50_daily/2026-11-17.md --input /tmp/nota.md
python3 scripts/content.py plan-move --path 30_resources/origen.md --destination 30_resources/destino.md
python3 scripts/content.py plan-retire --path 30_resources/origen.md
```

`template --type` imprime la plantilla recomendada sin escribir en la wiki. Los tipos disponibles son `decision`, `convention`, `lesson`, `project-context`, `area`, `daily`, `pending-decision`, `export`, `resource`, `map` y `archive`. Si una plantilla local anterior carece de metadatos, la salida incorpora los campos ausentes de la plantilla distribuida sin cambiar el archivo local ni su contenido personalizado. Completa y revisa la salida antes de crear; `create` rechaza los marcadores conocidos sin completar.

`--input` señala un archivo local preparado por la persona o el agente; no cambia el ámbito de la wiki. En `update`, la comprobación automática de enlaces es parcial y no sustituye la revisión del operador. El parser de front matter admite claves simples, escalares y listas simples como las de las plantillas; rechaza las construcciones que no puede validar. No interpreta YAML general.

`plan-move` y `plan-retire` son de solo lectura. Devuelven origen, destino y un inventario de archivos regulares de la wiki con SHA-256; rechazan destinos existentes, symlinks y errores de lectura. El inventario no identifica ni valida referencias y no constituye autorización para escribir. La persona o agente debe inspeccionar el contenido pertinente, incluyendo enlaces Markdown, metadatos, índices, código y recursos, sin asumir que una búsqueda textual los encuentra todos.

Para aplicar una operación autorizada, adquiere el lock manual, vuelve a generar el plan y compara el inventario y las huellas con los revisados. Si hay cambios o no puedes determinar todos los efectos, detente. Bajo el lock, prepara y revisa los cambios de contenido, referencias, índice y log; aplícalos sin sobrescribir destinos. Tras completarlos, verifica contenido, enlaces y `check`, y libera el lock. Si falla o se interrumpe, conserva el lock y sigue la recuperación. La revisión es responsabilidad del operador y la operación entre archivos no es atómica.

Las propuestas de migración anteriores al esquema actual conservan sus metadatos originales al actualizarse o retirarse. Una actualización puede mantener el esquema anterior o completar el actual, preservando identidad, fuente y fecha de creación.

## Coordinación de escrituras

Las escrituras de `content.py`, `wiki.sh` y `wiki.ps1` adquieren de forma exclusiva `wiki/.local-mem.lock` antes de leer o cambiar los archivos de la operación. El archivo visible registra operación, proceso, anfitrión y alcance; Python añade las rutas preparadas antes de publicar. Una segunda escritura falla mientras exista. Las lecturas y `check` no adquieren el lock y pueden observar una operación en curso.

Al terminar correctamente, el proceso libera el lock. Python también lo libera tras un error anterior a la publicación o una reversión completa; los scripts de instancia lo conservan ante errores. Una interrupción o reversión incompleta puede dejarlo presente. No se elimina por tiempo ni se recupera automáticamente.

Para recuperar: inspecciona el lock y confirma en el anfitrión indicado que el proceso ya no está activo; revisa las rutas y el log, resuelve manualmente cualquier cambio parcial y ejecuta `check`. Solo después de esa revisión, una persona autorizada elimina `wiki/.local-mem.lock`. Un lock sin plan legible también exige esa revisión. El lock y plan no son memoria documental.

La coordinación es cooperativa entre las tres interfaces. Git, editores y otros procesos que no respeten el lock pueden escribir simultáneamente; las comprobaciones de conflicto siguen siendo necesarias. No hay atomicidad entre archivos ni recuperación automática tras una interrupción.

Para una operación manual, desde la raíz de la skill adquiere el mismo archivo de forma exclusiva antes de preparar el cambio. En shell POSIX, por ejemplo:

```sh
( set -C; printf 'operation: manual\npid: %s\nhost: %s\nstage: prepare\n' "$$" "$(hostname)" > wiki/.local-mem.lock )
```

Si falla, no escribas. Añade al plan las rutas y efectos previstos, realiza y verifica la operación autorizada y elimina el lock solo al terminar. Si falla o se interrumpe, conserva el lock para recuperación. En PowerShell usa `[System.IO.File]::Open` con `FileMode.CreateNew`, escribe y cierra el plan; el mismo criterio se aplica a su liberación. La creación exclusiva, no una comprobación previa de existencia, decide quién adquiere el turno.
