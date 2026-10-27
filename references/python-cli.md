# Contrato del CLI Python

`ato-mem` es una interfaz complementaria de lectura para vaults formato `3`.
No reemplaza `scripts/vault.sh` ni `scripts/vault.ps1`, no modifica archivos,
no crea cachés ni índices, no consulta la red y no hace inferencia semántica.
`build` y `retrieve` preparan y consultan un corpus transitorio; no son una
implementación RAG.

La ubicación técnica reservada para futuras implementaciones persistentes es
`99_runtime/rag/`. Esta versión no la crea ni la consume: el CLI no escribe
manifests, bases, índices ni archivos bajo esa ruta.

## Instalación

Requiere Python `3.11+` y `pip` en el anfitrión:

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install .
```

El runtime no tiene dependencias externas. El paquete se llama `ato-ai-mem`,
el módulo es `ato_ai_mem` y el ejecutable es `ato-mem`.

## Comandos

```text
ato-mem check  --vault PATH [--format text|json]
ato-mem find   --vault PATH --pattern REGEX [--ignore-case] [--format text|json]
ato-mem relate --vault PATH [--format text|json]
ato-mem build  --vault PATH [--include GLOB] [--exclude GLOB] [--format json]
ato-mem retrieve --vault PATH --query TEXT [--limit 5] [--include GLOB] [--exclude GLOB] [--format json]
```

`--vault` debe apuntar explícitamente a una vault formato `3`, sea la vault
fuente `vault/` o una vault consumidora `mem/vault/`. El CLI no descubre una
vault por proximidad ni usa `--target`.

### `check`

Audita sin mutar:

- estructura mínima legible de la vault;
- front matter de registros en `20_domains/*/records/`;
- campos requeridos, IDs, fechas, tipos, estados, `scope`, listas y enlaces;
- relaciones locales de `related`, `supersedes` y `superseded_by`;
- presencia de registros activos y retirados en la sección correspondiente de
  cada `INDEX.md`.

El parser cubre el subconjunto documentado de front matter: escalares,
`null`, listas indentadas y `[]`. No es un parser YAML general.

### `find`

Busca con `re` de Python, línea a línea, en todos los archivos `.md` bajo la
vault. Incluye índices, guías, registros retirados y archivo histórico. La
búsqueda es sensible a mayúsculas por defecto y `--ignore-case` la hace
insensible. Los archivos y directorios simbólicos no se siguen.

### `relate`

Extrae relaciones declaradas de enlaces Markdown locales y de los campos
`related`, `supersedes` y `superseded_by`. Ignora URLs externas, resuelve
anchors locales y conserva como hallazgo cada destino que no exista. En front
matter se prueban primero rutas relativas al registro y después rutas
relativas a la raíz del dominio, compatibilidad necesaria para las rutas de
proyecto documentadas por la vault.

### `build`

Construye en memoria un corpus estructural y lo emite en JSON. Incluye todos
los archivos `.md` por defecto; `--include` y `--exclude` aceptan globs
repetibles sobre rutas relativas POSIX, y `exclude` tiene precedencia.

El front matter se conserva como `metadata`. Cada heading ATX inicia una
sección; el contenido previo al primer heading es la sección raíz. Cada item
incluye `id`, `path`, `line_start`, `line_end`, `heading_path`, `text` y
`metadata`. El ID es determinista: `path#L<line_start>-L<line_end>`.

Un front matter sintácticamente inválido produce un diagnóstico visible y no
descarta el texto recuperable. La operación no escribe archivos.

### `retrieve`

Reconstruye el corpus en memoria y aplica retrieval léxico. La consulta se
tokeniza con `casefold()` y tokens Unicode; la semántica es `OR`. El ranking
prioriza cobertura de términos, número de coincidencias, coincidencias en
headings y finalmente ruta/línea para resolver empates de forma determinista.

Cada resultado incluye `path`, líneas, `heading_path`, `snippet`, `score`,
`matched_terms`, `term_hits`, `citation` y relaciones declaradas del archivo.
El límite predeterminado es `5` y el máximo `50`. No genera respuestas ni
ensambla prompts.

## Salida

El formato por defecto es texto. `--format json` produce una línea JSON con
este sobre estable:

```json
{
  "schema": 1,
  "command": "check",
  "status": "ok|findings|error",
  "summary": {},
  "items": []
}
```

Los elementos de `check` contienen `path`, `line`, `code` y `message`; los de
`find` contienen `path`, `line` y `snippet`; los de `relate` contienen
`source`, `relation`, `target` y `resolved`; los de `build` y `retrieve`
conservan los campos descritos en sus secciones.

Los códigos de salida son:

- `0`: ejecución correcta sin hallazgos;
- `1`: hallazgos, relaciones no resueltas o ninguna coincidencia;
- `2`: error de uso, regex inválida, ruta inválida o fallo de lectura.

La versión inmediata no incluye escritura de reportes, plugins, proveedores
NLP, embeddings, bases vectoriales, generación RAG ni automatización. El
roadmap y sus gates están en [references/retrieval-roadmap.md](retrieval-roadmap.md).
