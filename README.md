# ato-ai-skill-mem

`ato-ai-skill-mem` administra memoria curada y local para un proyecto y sus
agentes. La memoria es Markdown versionable: no es una base de datos ni una
captura automática de conversaciones. Es una base técnica que otros proyectos
pueden incorporar a flujos de memoria o de segundo cerebro sin convertir esta
skill en ese producto.

## Modelo

El repositorio es la definición canónica del skill. Cada proyecto consumidor
instala una instancia híbrida en `mem/`:

```text
consumer-project/
├── .ato-ai-skill-mem.yml              # contrato opcional de integración
├── .agents/skills/ato-ai-project-mem/ # adaptador opcional de Codex
│   └── SKILL.md                        # regular; dirige a mem/SKILL.md
└── mem/
    ├── SKILL.md      -> ato-ai-skill-mem/SKILL.md
    ├── VERSION       -> ato-ai-skill-mem/VERSION
    ├── WORKSPACE_FORMAT -> ato-ai-skill-mem/WORKSPACE_FORMAT
    ├── references/   -> ato-ai-skill-mem/references/
    ├── templates/    -> ato-ai-skill-mem/templates/
    ├── scripts/      -> ato-ai-skill-mem/scripts/
    └── vault/        # real, local y versionado por el consumidor
        ├── INDEX.md
        ├── .ato-ai-skill-mem-version.yml
        └── records/
```

El `vault/` de este repositorio es un vault de fuente: contiene la
memoria documental de este proyecto, no enlaces simbólicos ni datos de
consumidores. Las instancias no comparten registros entre sí.

## Contextos de uso

Una skill, un agente o un proyecto pueden invocar esta capacidad. En todos los
casos, el vault pertenece al proyecto que origina el conocimiento; la
ubicación de la skill o del agente no crea una memoria independiente.

| Contexto | Cómo se incorpora | Estado |
| --- | --- | --- |
| Skill en proyecto | El proyecto instala `mem/`; una skill local puede delegar en `mem/SKILL.md`. | Instalación de proyecto soportada. |
| Skill en agente | Las instrucciones del agente referencian la skill y señalan el proyecto objetivo. | Integración manual; el bootstrap no instala adaptadores genéricos de agentes. |
| Skill en skill | Una skill compuesta declara `ato-ai-skill-mem` como dependencia y delega las operaciones de memoria. | Composición documental; el anfitrión resuelve e invoca la dependencia. |

Para un consumidor, el destino soportado es `mem/vault/` del proyecto
anfitrión. Los dos últimos patrones no habilitan un vault privado para la
skill o el agente. Si un repositorio que contiene una skill necesita memoria
para su propio desarrollo, puede instalar la instancia como proyecto
consumidor y mantener `mem/vault/` separado de las memorias de los
proyectos que atienda. El anfitrión debe preservar las reglas de evaluación,
compatibilidad y escritura explícita de `SKILL.md`.

## Cómo funciona

La definición del skill se mantiene centralizada; cada consumidor conserva
solamente su propia memoria. El flujo evita cargar contexto innecesario y no
persiste nada sin una petición explícita.

~~~text
skill canónico
  ├── SKILL.md + VERSION + WORKSPACE_FORMAT + references + templates + scripts
  │        │
  │        └── bootstrap ──> proyecto-consumidor/mem/
  │                              ├── enlaces simbólicos canónicos
  │                              └── vault/ local
  │
  └── tarea del agente
           │
           ├── lee INDEX.md
           ├── abre solo registros relevantes
           └── petición humana explícita
                    └── crea/actualiza/retira registro + INDEX.md
~~~

Cada registro es un archivo Markdown fechado con tipo, estado, autor, evidencia
y enlaces relacionados. Cuando una decisión queda invalidada, se conserva con
`status: retired` y enlaza a su sucesora; no se borra.

Los datos del vault pueden viajar con el repositorio del proyecto al
versionar y sincronizar ese repositorio con Git. Esto sincroniza las copias de
la memoria de ese mismo proyecto; no mezcla workspaces ni distribuye
automáticamente conocimiento entre proyectos. Para compartir una conclusión,
una persona la selecciona y la incorpora al repositorio o memoria común que
corresponda.

El bootstrap prevalida los tres destinos enlazados antes de crear la instancia.
Si encuentra un conflicto existente, falla sin reemplazar archivos ni crear
enlaces nuevos. Después crea solamente el scaffold que falta y preserva
cualquier vault/ ya existente.

## Instalar una instancia

macOS/Linux:

```sh
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project
```

Windows PowerShell:

```powershell
.\scripts\bootstrap.ps1 -Target C:\path\to\consumer-project
```

Para exponer la memoria como un skill local de Codex, añade la integración de
forma explícita:

```sh
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project --integrate-codex
```

Esto crea `.ato-ai-skill-mem.yml` en la raíz del consumidor y un adaptador
regular en `.agents/skills/ato-ai-project-mem/SKILL.md`. El adaptador delega en
`mem/SKILL.md` y usa solamente `mem/vault/`; no es un enlace hacia el
repositorio fuente. `--status` informa si la integración está alineada, ausente
o en conflicto. El bootstrap rechaza configuraciones o adaptadores existentes
que no correspondan al contrato y nunca modifica `AGENTS.md`.

Para integrar la consulta selectiva en un `AGENTS.md` consumidor, copia el
bloque de integración de [references/agents-integration.md](references/agents-integration.md).
El bootstrap no modifica instrucciones de agentes.

Los scripts requieren permisos para crear symlinks. Si el sistema no los
permite, fallan con un diagnóstico y no generan una copia divergente. En
Windows habilita Developer Mode o ejecuta una terminal con el permiso adecuado.

Los scripts son idempotentes: validan enlaces existentes y crean solo el
scaffolding ausente. `mem/SKILL.md`, `mem/VERSION`,
`mem/WORKSPACE_FORMAT`, `mem/references/`, `mem/templates/` y `mem/scripts/`
apuntan siempre a la fuente canónica; `mem/vault/` nunca se sobrescribe.

## Versiones

`VERSION` declara la versión del skill; `WORKSPACE_FORMAT` declara el formato
de datos que puede operar. Un release se considera alineado cuando el checkout
está en `master` y el mismo commit tiene el tag `v<VERSION>`.
Consulta el estado, sin modificar el proyecto, con:

```sh
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project --status
```

El vault conserva su propia marca visible en
`vault/.ato-ai-skill-mem-version.yml`. El formato `1` es heredado y requiere
migración explícita al formato `2` mediante `--migrate-workspace-to-vault`.
Mientras el skill permanezca en `0.x`, una versión menor puede introducir
cambios incompatibles documentados; `1.0.0` será el primer contrato estable.
Para migrar el vault fuente existente usa
`--migrate-source-workspace-to-vault`; ambas operaciones rechazan destinos
existentes y conservan el contenido Markdown.
Para actualizar solo esa marca tras validar un release nuevo, usa
`--update-vault`; requiere una instancia existente y una fuente
`release-aligned`, y no modifica `INDEX.md` ni registros.

Al cargar el skill, el agente debe comunicar un diagnóstico de fuente,
versiones, formatos, compatibilidad y modo recomendado antes de operar
memoria. El modo puede ser operación compatible, desarrollo sin promoción,
revisión de vault más nuevo, planificación de migración o instalación
pendiente. La revisión Git queda como evidencia auditable y no cambia por sí
sola el modo. Esta evaluación recomienda acciones; no modifica el vault.

El manifiesto incluye `vault_kind`: `consumer` en cada
`mem/vault/` y `source` en el `vault/` de este repositorio. Para
consultar el segundo sin crear una instancia, ejecuta:

```sh
./scripts/bootstrap.sh --source-status
```

Después de crear un release, solo un checkout limpio en `master` cuyo `HEAD`
sea el tag `v<VERSION>` puede actualizar la referencia del vault de fuente:

```sh
./scripts/bootstrap.sh --update-source-vault
```

La operación solo escribe el manifiesto; no crea tags ni commits. El marcador
queda asociado al último release validado aunque el desarrollo posterior avance
en otra revisión. Usar `--target` sobre la raíz de este repositorio se rechaza
para evitar una auto-instalación recursiva.

## Operación

1. Integra el adaptador de Codex con `--integrate-codex` o copia el snippet
   manual en AGENTS.md si quieres activar memoria mediante instrucciones de
   proyecto.
2. El agente lee vault/INDEX.md y abre solo los registros pertinentes.
3. Una persona pide explícitamente registrar, actualizar, retirar o reemplazar
   memoria.
4. El agente usa una plantilla, actualiza el registro y mantiene el índice
   coherente.

Consulta [SKILL.md](SKILL.md) para el comportamiento del agente y
[references/instance-contract.md](references/instance-contract.md) para el
contrato de los registros. Si existe conflicto, `SKILL.md` tiene precedencia
sobre este README.

## Límites

- No guarda secretos, credenciales ni datos sensibles.
- No captura conversaciones ni escribe en segundo plano.
- No incorpora RAG, índices vectoriales, servicios externos ni sincronización
  automática de memoria entre proyectos.
- Los registros se versionan por defecto con el proyecto consumidor.

## Validación antes de ampliar

Antes de añadir automatización o nuevas capacidades, dos proyectos consumidores
deben completar instalación, lectura selectiva y una escritura solicitada
explícitamente. Documenta la fricción repetida como un registro de memoria del
proyecto antes de proponer una ampliación.
