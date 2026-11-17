# ato-ai-skill-mem

Skill de memoria documental Markdown, legible por personas y versionable.
La carpeta de esta skill es su ámbito: la única memoria que consulta es
`vault/` en esta misma raíz.

## Uso

Instala o copia la carpeta completa del skill en la ubicación elegida. Incluye
`SKILL.md`, `vault/`, `scripts/`, `templates/` y `references/`. No ejecutes un
bootstrap ni configures un proyecto destino. Al activarse para una tarea que
necesite contexto duradero, la skill verifica `vault/` y lee solo el dominio
pertinente.

La lectura no autoriza escrituras. Crear, actualizar, mover o retirar memoria
requiere una petición humana explícita.

## Vault

El formato `3` organiza la memoria con `vault/AGENTS.md`, índices, mapas y
dominios `20_domains/<id>/`. Cada dominio es una unidad Markdown con metadata,
índice, registros y recursos. El contrato completo está en
[instance-contract.md](references/instance-contract.md).

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
