# ato-ai-skill-mem

`ato-ai-skill-mem` administra memoria curada y local para un proyecto y sus
agentes. La memoria es Markdown versionable: no es una base de datos, una
captura automática de conversaciones ni un segundo cerebro.

## Modelo

El repositorio es la definición canónica del skill. Cada proyecto consumidor
instala una instancia híbrida en `mem/`:

```text
consumer-project/
└── mem/
    ├── SKILL.md      -> ato-ai-skill-mem/SKILL.md
    ├── references/   -> ato-ai-skill-mem/references/
    ├── templates/    -> ato-ai-skill-mem/templates/
    └── workspace/    # real, local y versionado por el consumidor
        ├── INDEX.md
        ├── .ato-ai-skill-mem-version.yml
        └── records/
```

El `workspace/` de este repositorio sigue el mismo contrato y contiene la
memoria de este proyecto. Las instancias no comparten registros entre sí.

## Cómo funciona

La definición del skill se mantiene centralizada; cada consumidor conserva
solamente su propia memoria. El flujo evita cargar contexto innecesario y no
persiste nada sin una petición explícita.

~~~text
skill canónico
  ├── SKILL.md + references + templates
  │        │
  │        └── bootstrap ──> proyecto-consumidor/mem/
  │                              ├── enlaces simbólicos canónicos
  │                              └── workspace/ local
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

El bootstrap prevalida los tres destinos enlazados antes de crear la instancia.
Si encuentra un conflicto existente, falla sin reemplazar archivos ni crear
enlaces nuevos. Después crea solamente el scaffold que falta y preserva
cualquier workspace/ ya existente.

## Instalar una instancia

macOS/Linux:

```sh
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project
```

Windows PowerShell:

```powershell
.\scripts\bootstrap.ps1 -Target C:\path\to\consumer-project
```

Para integrar la consulta selectiva en un `AGENTS.md` consumidor, copia el
bloque de integración de [references/agents-integration.md](references/agents-integration.md).
El bootstrap no modifica instrucciones de agentes.

Los scripts requieren permisos para crear symlinks. Si el sistema no los
permite, fallan con un diagnóstico y no generan una copia divergente. En
Windows habilita Developer Mode o ejecuta una terminal con el permiso adecuado.

Los scripts son idempotentes: validan enlaces existentes y crean solo el
scaffolding ausente. `mem/templates/` apunta siempre a las plantillas
canónicas; `mem/workspace/` nunca se sobrescribe.

## Versiones

`VERSION` declara la versión del skill; `WORKSPACE_FORMAT` declara el formato
de datos que puede operar. Un release se considera alineado cuando el checkout
está en `master` y el mismo commit tiene el tag `v<VERSION>`.
Consulta el estado, sin modificar el proyecto, con:

```sh
./scripts/bootstrap.sh --target /absolute/path/to/consumer-project --status
```

El workspace conserva su propia marca visible en
`workspace/.ato-ai-skill-mem-version.yml`. El formato `1` se mantiene
compatible durante `0.x` y `1.x`, incluso si el manifiesto es heredado y no lo
declara. Para actualizar solo esa marca tras validar un release nuevo, usa
`--update-workspace`; requiere fuente `release-aligned` y no modifica
`INDEX.md` ni registros. Un cambio de formato solo podrá plantearse a partir
de `2.0.0`, mediante una migración confirmada por una persona.

Al cargar el skill, el agente debe comunicar un diagnóstico de fuente,
versiones, formatos, compatibilidad y modo recomendado antes de operar
memoria. El modo puede ser operación compatible, desarrollo sin promoción,
revisión de discrepancia de versión, planificación de migración o instalación
pendiente. Esta evaluación recomienda acciones; no modifica el workspace.

## Operación

1. Integra el snippet manual en AGENTS.md si quieres activar memoria en ese
   proyecto.
2. El agente lee workspace/INDEX.md y abre solo los registros pertinentes.
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
- No incorpora RAG, índices vectoriales, servicios externos o sincronización.
- Los registros se versionan por defecto con el proyecto consumidor.

## Validación antes de ampliar

Antes de añadir automatización o nuevas capacidades, dos proyectos consumidores
deben completar instalación, lectura selectiva y una escritura solicitada
explícitamente. Documenta la fricción repetida como un registro de memoria del
proyecto antes de proponer una ampliación.
