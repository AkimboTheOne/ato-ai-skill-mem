---
name: ato-ai-source-mem
description: Consulta y administra la memoria documental del repositorio fuente de ato-ai-skill-mem. Úsala cuando una tarea de este repositorio requiera decisiones, convenciones, lecciones o contexto persistente.
---

# Memoria Fuente (de ato-ai-skill-mem)

Este adaptador es exclusivo de `ato-ai-skill-mem`. El comportamiento canónico
está en `SKILL.md` de la raíz del repositorio y su memoria documental está
exclusivamente en `vault/`.

1. Lee y sigue `SKILL.md`, `VERSION`, `VAULT_FORMAT` y, si existe,
   `vault/.ato-ai-skill-mem-version.yml` antes de operar memoria.
2. Ejecuta `scripts/bootstrap.sh --source-status` o el equivalente de
   PowerShell para diagnosticar versión, formato, compatibilidad y modo sin
   escribir.
3. Solo en operación compatible o desarrollo sin promoción, lee
   `vault/AGENTS.md`, `vault/_indexes/INDEX.md` y el dominio pertinente.
4. Para ampliar conocimiento, selecciona o crea un dominio de forma explícita
   y sigue sus instrucciones. Si no hay destino claro, prepara una propuesta
   en `vault/00_inbox/decisions-pending/`; no clasifiques por similitud.
5. Usa `scripts/vault.sh` o `scripts/vault.ps1` con `vault/` solo ante petición
   humana explícita: `init-layout`, `create-domain`, `check`,
   `migration-plan` y `migration-apply`. Después de una operación solicitada,
   ejecuta `check`. Consulta `references/vault-operations.md` para parámetros,
   efectos y límites.

No uses `mem/vault/`, no ejecutes `--target .` y no copies, reemplaces ni
sincronices `vault/` con vaults de proyectos consumidores.
