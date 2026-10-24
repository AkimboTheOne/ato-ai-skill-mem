---
name: ato-ai-skill-mem
description: Administra memoria curada, local y versionable para un proyecto y sus agentes. Úsala cuando una tarea requiera consultar, registrar, actualizar, retirar o reemplazar decisiones, convenciones, aprendizajes o contexto de proyecto.
---

# ATO AI Skill Mem

## Propósito

Este skill mantiene una memoria explícita y legible por personas en
`workspace/`. Es una memoria compartida por el proyecto: cada registro indica
su autor, pero no existen subespacios separados por agente en el baseline.

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

## Lectura selectiva

1. Ejecuta la evaluación de carga antes de usar o modificar memoria.
2. Lee `workspace/INDEX.md`.
3. Identifica los enlaces relevantes para la tarea actual.
4. Abre solo esos registros en `workspace/records/`.
5. Explica qué información de memoria modificó la decisión si resulta material.

No cargues todos los registros por defecto.

## Evaluación de carga

Al cargar el skill, lee `VERSION`, `WORKSPACE_FORMAT` y, si existe,
`workspace/.ato-ai-skill-mem-version.yml`. Expón un diagnóstico breve y
visible con: estado de la fuente, versión fuente y registrada, formato fuente
y registrado, compatibilidad de datos y modo recomendado. Si el instalador
está disponible, `--status` aporta esos mismos datos sin escribir.

Elige el modo con estas reglas:

- **Operación compatible:** el formato es compatible y el workspace está
  alineado, heredado o requiere una actualización compatible. Lee y usa los
  registros normalmente; recomienda actualizar el manifiesto solo bajo las
  condiciones de versionado.
- **Desarrollo sin promoción:** la fuente no es `release-aligned`. Puede leer
  datos compatibles, pero no recomienda ni ejecuta una actualización de
  manifiesto.
- **Fuente o workspace más nuevo:** la versión registrada es mayor, o la
  revisión difiere sin un avance válido. No rebaja el manifiesto; recomienda
  seleccionar la fuente publicada correspondiente o revisar la discrepancia.
- **Planificación de migración:** el formato es incompatible. No escribe ni
  interpreta registros como compatibles; explica el impacto, propone pasos y
  espera confirmación humana explícita.
- **Instalación pendiente:** el workspace no existe. Recomienda instalar la
  instancia; no lo hace salvo petición humana explícita.

## Escritura explícita

Solo modifica `workspace/` cuando una persona pida expresamente registrar,
actualizar, retirar o reemplazar memoria. Una propuesta de cambio puede
presentarse sin escribir archivos.

Al crear un registro:

1. Usa una plantilla de `templates/records/`.
2. Nómbralo `YYYY-MM-DD--slug.md` dentro de `workspace/records/`.
3. Completa el front matter y la evidencia disponible.
4. Añade un enlace y un resumen de una línea a `workspace/INDEX.md`.

Al reemplazar un registro:

1. Crea el registro sucesor.
2. Cambia el anterior a `status: retired`.
3. Añade `superseded_by` en el anterior y `supersedes` en el nuevo.
4. Sustituye el enlace activo en `workspace/INDEX.md`; conserva la referencia
   histórica en la sección de retirados.

No borres un registro solo porque haya quedado obsoleto.

## Restricciones

- No guardes secretos, credenciales, tokens, datos personales sensibles ni
  transcripciones completas de conversaciones.
- No escribas de manera automática al cerrar una tarea o sesión.
- No introduzcas bases vectoriales, RAG, servicios externos, sincronización ni
  ejecución en segundo plano.
- No sobrescribas contenido existente durante una actualización de la
  instalación.

## Versionado y alineación

`VERSION` declara la versión SemVer del skill y `WORKSPACE_FORMAT` el formato
de datos que el skill sabe operar. Una versión distribuible debe corresponder
al tag Git `v<VERSION>` aplicado al commit de `master`.

`workspace/.ato-ai-skill-mem-version.yml` es un manifiesto visible, separado
de los registros de memoria: guarda la versión, revisión, tag y fechas de la
última inicialización o actualización explícita, incluido su
`workspace_format`. No contiene secretos ni estado inferido. Si el manifiesto
no existe o no incluye ese campo, el workspace se trata como formato heredado
`1`.

El formato `1` debe mantenerse compatible durante `0.x` y `1.x`: versiones
nuevas del skill pueden operar esos datos sin reescribir registros. Una futura
migración de paradigma solo puede introducirse a partir de `2.0.0`, con un
formato nuevo, pasos documentados y confirmación humana explícita. Detectar un
formato incompatible debe producir un diagnóstico y propuesta, no una
migración automática.

Usa `scripts/bootstrap.sh --target <project> --status` (o el equivalente de
PowerShell) para inspeccionar la alineación sin modificar datos. Si el
workspace requiere actualizar su marcador, usa `--update-workspace`; esta
rutina requiere una fuente `release-aligned` y preserva `INDEX.md` y
`records/` íntegramente. Una fuente que no esté en `master` y taggeada se
informa como `not-release-aligned`; no debe presentarse como una distribución
publicada ni usarse para actualizar una marca existente.

Consulta [references/instance-contract.md](references/instance-contract.md)
para el formato canónico, [references/agents-integration.md](references/agents-integration.md)
para la integración manual en proyectos consumidores y [templates/](templates/)
para las plantillas.
