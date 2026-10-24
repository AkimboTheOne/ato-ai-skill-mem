---
name: ato-ai-source-mem
description: Consulta y administra la memoria documental del repositorio fuente de ato-ai-skill-mem. Úsala cuando una tarea de este repositorio requiera decisiones, convenciones, lecciones o contexto persistente.
---

# Memoria del repositorio fuente

Este adaptador es exclusivo de `ato-ai-skill-mem`. El comportamiento canónico
está en `SKILL.md` de la raíz del repositorio y su memoria documental está
exclusivamente en `workspace/`.

1. Lee y sigue `SKILL.md`, `VERSION`, `WORKSPACE_FORMAT` y, si existe,
   `workspace/.ato-ai-skill-mem-version.yml` antes de operar memoria.
2. Ejecuta `scripts/bootstrap.sh --source-status` o el equivalente de
   PowerShell para diagnosticar versión, formato, compatibilidad y modo sin
   escribir.
3. Solo en operación compatible o desarrollo sin promoción, lee
   `workspace/INDEX.md` y los registros pertinentes.
4. Escribe memoria únicamente por petición humana explícita.

No uses `mem/workspace/`, no ejecutes `--target .` y no copies, reemplaces ni
sincronices `workspace/` con workspaces de proyectos consumidores.
