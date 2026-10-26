---
name: ato-ai-project-mem
description: Consulta la memoria curada del proyecto actual cuando una tarea requiera decisiones, convenciones, lecciones o contexto persistente del proyecto.
---

# Memoria local del proyecto

Este adaptador es el punto de entrada del consumidor. La fuente canónica de
reglas es `mem/SKILL.md`; la única vault de este proyecto es `mem/vault/`.

Activa el skill para tareas que dependan de memoria del proyecto, no para
trabajo ordinario. Sigue `mem/SKILL.md` para diagnosticar, obtener la
composición mínima, supervisar la vault cuando corresponda y leer solo el
dominio pertinente. Si el destino o el contexto no está claro, presenta una
propuesta sin persistirla.

No accedas a la vault fuente, no copies ni sincronices vaults. Las reglas
canónicas definen toda autoridad y operación persistente.
