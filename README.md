# ato-ai-skill-mem (local-mem)

Este repositorio contiene `local-mem`, un Módulo Local de Memoria documental
Markdown, legible por personas y versionable. La skill consulta únicamente la
`vault/` junto a su propio `SKILL.md`; cada instalación mantiene un ámbito
separado aunque otras copias estén disponibles para otros plugins o agentes.

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
vez activada, cada copia solo consulta la `vault/` junto a su propio
`SKILL.md`.

## Uso

Instala o copia los componentes de la skill en una sola carpeta llamada
`local-mem`: `SKILL.md`,
`VERSION`, `VAULT_FORMAT`, `agents/`, `vault/`, `scripts/`, `templates/` y
`references/`. La raíz resultante contiene tanto la skill como su única vault.
No copies configuración local (`.codex/`), metadatos Git (`.git/`), pruebas ni
artefactos de desarrollo. No ejecutes un bootstrap ni configures un proyecto
destino. Al activarse para una tarea que necesite contexto duradero, la skill
verifica `vault/` y lee solo el dominio pertinente.

La lectura no autoriza escrituras. Crear, actualizar, mover o retirar memoria
requiere una petición humana explícita.

## Vault

El formato `3` organiza la memoria con `vault/AGENTS.md`, índices, mapas y
dominios `20_domains/<id>/`. Cada dominio es una unidad Markdown con metadata,
índice, registros y recursos. El contrato completo está en
[instance-contract.md](references/instance-contract.md).
Si actualizas una instalación antigua que guardaba memoria en `mem/vault/`,
sigue la [guía de migración manual](references/legacy-vault-migration.md).

Para revisar o administrar la estructura de la única vault:

```sh
./scripts/vault.sh check
./scripts/vault.sh create-domain --id arquitectura --title Arquitectura
```

PowerShell ofrece los mismos comandos con `scripts/vault.ps1`. Los comandos
operan siempre en `vault/` junto a esta skill y no admiten otra ruta.

## Versiones y publicación

`VERSION` identifica la versión del skill y `VAULT_FORMAT` la del layout de
datos. Son independientes. El gate de integración clasifica SemVer sobre el
diff final; la guía de publicación está en
[release-readiness.md](references/release-readiness.md).

## Límites

La skill no implementa RAG operativo, embeddings, bases vectoriales,
sincronización, fusión de memorias ni ejecución en segundo plano. Las
definiciones de instalación consumidora, adaptadores y CLI independiente se
conservan como historia en [references/history/README.md](references/history/README.md).
