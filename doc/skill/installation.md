# ato-ai-skill-mem (local-mem)

Esta guía explica la instalación y el uso de `local-mem`, un Módulo Local de Memoria documental
Markdown, legible por personas y versionable. La skill consulta únicamente la
`wiki/` junto a su propio `SKILL.md`; cada instalación mantiene un ámbito
separado aunque otras copias estén disponibles para otros plugins o agentes.

En el repositorio fuente, `wiki/` es solo el layout base vacío. La
documentación y el historial del proyecto viven en `doc/` y no se copian como
datos de una instancia.

## Instalación desde Git

El nombre remoto del repositorio se conserva como `ato-ai-skill-mem`. Para que
el directorio de la skill coincida con el ID `local-mem` exigido por Agent
Skills, clónalo indicando el destino:

```sh
git clone git@github.com:AkimboTheOne/ato-ai-skill-mem.git local-mem
```

Git usa el directorio indicado en el comando; el repositorio no puede imponer
el nombre de destino. Si tienes varias instalaciones, colócalas en rutas padre
separadas y conserva el nombre final `local-mem` en cada una.

`local-mem` identifica el tipo de skill, no un plugin o proyecto concreto. Si
el anfitrión carga varias copias con ese mismo ID, la selección entre ellas
depende del anfitrión; la skill no puede garantizar qué copia se invocará. Una
vez activada, cada copia solo consulta la `wiki/` junto a su propio
`SKILL.md`.

## Uso

Instala o copia los componentes de la skill en una sola carpeta llamada
`local-mem`: `SKILL.md`,
`VERSION`, `WIKI_FORMAT`, `agents/`, `wiki/`, `scripts/`, `templates/` y
`references/`. La raíz resultante contiene tanto la skill como su única wiki.
No copies configuración local (`.codex/`), metadatos Git (`.git/`), pruebas ni
artefactos de desarrollo. No ejecutes un bootstrap ni configures un proyecto
destino. Al activarse para una tarea que necesite contexto duradero, la skill
verifica `wiki/` y lee solo el dominio pertinente.

La lectura no autoriza escrituras. Crear, actualizar, mover o retirar memoria
requiere una petición humana explícita.

## Wiki

El formato `3` organiza la memoria con `wiki/AGENTS.md`, índices, mapas y
dominios `20_domains/<id>/`. Cada dominio es una unidad Markdown con metadata,
índice, registros y recursos. El contrato completo está en
[instance-contract.md](../../references/instance-contract.md).
Si actualizas una instalación que aún guarda su memoria en `vault/`, sigue la
[guía de migración manual](../../references/legacy-wiki-migration.md). La skill nueva
no consulta ni traslada esa ruta automáticamente. La ubicación histórica
retirada `mem/vault/` tampoco se reconoce como una raíz activa.

Para revisar o administrar la estructura de la única wiki:

```sh
./scripts/wiki.sh check
./scripts/wiki.sh create-domain --id arquitectura --title Arquitectura
```

PowerShell ofrece los mismos comandos con `scripts/wiki.ps1`. Los comandos
operan siempre en `wiki/` junto a esta skill y no admiten otra ruta.

## Desarrollo y validación

La validación de metadatos usa PyYAML únicamente como dependencia de desarrollo.
Con Python 3.11 o posterior, prepara el entorno una vez por clon:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python scripts/validate-skill.py
```

En Windows usa `py -3 -m venv .venv` y sustituye `.venv/bin/python` por
`.venv\Scripts\python.exe` en los dos comandos siguientes. Si se elimina el
entorno, vuelve a crearlo e instalar las dependencias. El validador es una
copia de desarrollo de `skill-creator`; CI ejecuta el mismo comando sobre una
copia temporal llamada `local-mem`.

## Versiones y publicación

`VERSION` identifica la versión del skill y `WIKI_FORMAT` la del layout de
datos. Son independientes. El gate de integración clasifica SemVer sobre el
diff final; la guía de publicación está en
[release-readiness.md](../../references/release-readiness.md).

## Límites

La skill no implementa RAG operativo, embeddings, bases vectoriales,
sincronización, fusión de memorias ni ejecución en segundo plano. Las
definiciones de instalación consumidora, adaptadores y CLI independiente se
conservan como historia en [references/history/README.md](../../references/history/README.md).

### Operaciones de contenido

La skill orienta la consulta y los cambios explícitos sobre su wiki. Los flujos, las plantillas recomendadas y el asistente Python se describen en [operaciones de contenido](../../references/content-operations.md).
