---
name: ato-ai-project-mem
description: Consulta y administra la memoria curada del proyecto actual mediante ato-ai-skill-mem. Úsala cuando una tarea requiera decisiones, convenciones, lecciones o contexto persistente del proyecto.
---

# Memoria local del proyecto

Este adaptador define el punto de entrada del proyecto consumidor. La fuente
canónica del comportamiento está en `mem/SKILL.md`; la memoria de este proyecto
está exclusivamente en `mem/vault/`.

1. Lee y sigue `mem/SKILL.md` antes de consultar o modificar memoria.
2. Ejecuta `mem/scripts/bootstrap.sh --target . --status` o el equivalente de
   PowerShell para diagnosticar versión, formato y compatibilidad sin escribir.
3. Lee `mem/vault/INDEX.md` y solo los registros pertinentes.
4. Escribe memoria únicamente por petición humana explícita.

No uses el `vault/` del repositorio fuente del skill. No copies, reemplaces
ni sincronices `mem/vault/` con otra instancia.
